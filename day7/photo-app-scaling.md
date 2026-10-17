# SnapShare: Photo App Scaling Plan

## 1. Assumptions

SnapShare is a photo-sharing application where users upload photos and view photos in their feeds.

The following assumptions are used for the capacity estimates:

- Registered users: 10,000,000
- Daily active users (DAU): 10% of registered users
- Each active user uploads 1 photo per day.
- Each active user views 50 feed pages per day.
- Original photo size: 2 MB.
- Thumbnail size: 50 KB.
- Peak feed traffic is 5 times the average traffic.
- A day contains 86,400 seconds, and a year contains 365 days.
- Storage calculations use decimal units: 1 TB = 1,000 GB.

## 2. Capacity Estimates

### Daily active users

Daily active users are 10% of the 10 million registered users.

DAU = 10,000,000 × 0.10

**DAU = 1,000,000 users**

### Average photo uploads per second

Each daily active user uploads one photo per day.

Daily uploads = 1,000,000 × 1

Daily uploads = 1,000,000 photos

Average uploads per second:

1,000,000 ÷ 86,400 = 11.57

**Average uploads ≈ 11.6 photos per second**

### Average and peak feed views per second

Each active user views 50 feed pages per day.

Daily feed views = 1,000,000 × 50

Daily feed views = 50,000,000

Average feed views per second:

50,000,000 ÷ 86,400 = 578.7

**Average feed views ≈ 579 per second**

Peak feed views are assumed to be five times the average.

Peak feed views = 578.7 × 5

**Peak feed views ≈ 2,894 per second**

### Estimated yearly photo storage

Each photo produces an original image of 2 MB and a thumbnail of 50 KB.

**Original photos**

Daily original storage:

1,000,000 × 2 MB = 2,000,000 MB

Daily original storage = 2 TB

Yearly original storage:

2 TB × 365 = **730 TB per year**

**Thumbnails**

Daily thumbnail storage:

1,000,000 × 50 KB = 50,000,000 KB

Daily thumbnail storage = 50 GB

Yearly thumbnail storage:

50 GB × 365 = **18.25 TB per year**

**Total estimated yearly storage**

730 TB + 18.25 TB = **748.25 TB per year**

This estimate excludes database metadata, backups, replicas, temporary files, and additional storage overhead. It also assumes each original photo and thumbnail is stored once.

## 3. Workload Analysis

SnapShare is primarily a **read-heavy application** because users view approximately 50 feed pages per day but upload only one photo per day.

The system must support approximately 579 average feed views per second and nearly 2,894 feed views per second during peak periods.

The architecture should therefore prioritize:

- Fast feed delivery through a content delivery network (CDN).
- Caching frequently accessed feed data and photo metadata.
- Read replicas to distribute database read traffic.
- Object storage for original photos and thumbnails.
- Asynchronous background processing for thumbnail generation.

Uploads still require reliable write handling, but feed reads are expected to create the greater request volume.

## 4. Why Object Storage Instead of Database BLOBs?

Original photos and thumbnails should be stored in object storage rather than directly inside database BLOB columns.

Object storage is suitable because:

- It is designed to store large quantities of unstructured files.
- It can scale independently of the application database.
- It works with CDNs to deliver images efficiently.
- It avoids making the relational database responsible for serving large image files.
- It supports durable storage and can offer lifecycle policies for older files.

The database should store photo metadata, such as the photo ID, owner ID, caption, upload timestamp, and object-storage key or URL.

This keeps the relational database focused on structured data and relationships while object storage handles the image files.

## 5. Proposed System Architecture

```text
                         Users
                           |
                           v
                      DNS Service
                           |
                           v
                         CDN
                    /           \
          Cached photos       Uncached requests
                                  |
                                  v
                           Load Balancer
                                  |
                    +-------------+-------------+
                    |                           |
                    v                           v
              App Server 1                App Server 2
                    |                           |
                    +-------------+-------------+
                                  |
                     +------------+------------+
                     |                         |
                     v                         v
               Cache Layer               Primary Database
                     |                         |
                     |                         v
                     |                    Read Replica
                     |
                     v
               Feed Responses

       App Servers
            |
            v
       Object Storage <---------------- Thumbnail Worker
            ^                                  ^
            |                                  |
            +-------------------------- Job Queue
                                               ^
                                               |
                                      Upload Processing
```

The diagram is a simplified logical view. The job queue receives background-processing jobs from the application servers, and workers process those jobs asynchronously.

## 6. Architecture Components

### 1. DNS Service

DNS translates SnapShare's domain name into the appropriate service endpoint so users can reach the application.

### 2. Content Delivery Network (CDN)

The CDN caches and delivers frequently requested photos and thumbnails from locations closer to users, reducing latency and origin-server traffic.

### 3. Load Balancer

The load balancer distributes incoming application requests across multiple application servers to prevent one server from becoming overloaded.

### 4. Application Servers

At least two application servers handle API requests, authenticate users, validate uploads, retrieve feed metadata, and coordinate database and object-storage operations.

### 5. Cache Layer

A cache such as Redis stores frequently accessed feed data and metadata to reduce repeated database queries and improve response times.

### 6. Primary Database

The primary relational database stores structured information such as users, photo metadata, captions, relationships, and upload records while handling writes.

### 7. Read Replica

A read replica serves eligible database read queries, reducing the read workload on the primary database while replication keeps it updated with primary changes.

### 8. Object Storage

Object storage holds original photos and generated thumbnails, allowing image storage to scale independently of the relational database.

### 9. Job Queue

The queue holds background-processing jobs so photo uploads do not need to wait for every processing task to finish.

### 10. Thumbnail Worker

Background workers consume queued jobs, generate thumbnails, and save the resulting files to object storage.

## 7. Photo Upload Flow

1. A user selects a photo and submits it through the SnapShare client.
2. The request reaches the application through DNS and the load balancer.
3. An application server authenticates the user and validates the upload.
4. The original photo is uploaded to object storage, either through the application server or through a secure, time-limited upload URL.
5. The application records the photo metadata and storage key in the primary database.
6. The application publishes a thumbnail-generation job to the job queue.
7. The application returns an upload response to the client without waiting for thumbnail generation to finish.
8. A thumbnail worker consumes the job, generates the thumbnail, and saves it to object storage.
9. The completed photo and thumbnail can then be delivered through the CDN, and relevant feed caches can be refreshed or invalidated.

The implementation should account for failures between storage, database, and queue operations. Retries and idempotent processing help prevent duplicate work and inconsistent records.

## 8. Scaling Trade-offs

### Trade-off 1:
