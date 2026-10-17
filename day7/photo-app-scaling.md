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

This estimate excludes database metadata, backups, replicas, temporary files, and additional storage overhead. It assumes each original photo and thumbnail is stored once.

## 3. Workload Analysis

SnapShare is primarily a **read-heavy application** because users view approximately 50 feed pages per day but upload only one photo per day.

The system must support approximately 579 average feed views per second and nearly 2,894 feed views per second during peak periods.

The architecture should prioritize:

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
                           |
                 +---------+----------+
                 |                    |
          Cached Photos        API Requests
                                      |
                                      v
                               Load Balancer
                                      |
                         +------------+------------+
                         |                         |
                         v                         v
                   App Server 1              App Server 2
                         |                         |
                         +------------+------------+
                                      |
                         +------------+------------+
                         |            |            |
                         v            v            v
                       Cache      Primary DB   Object Storage
                      (Redis)         |        (Original Photos
                         |            |         and Thumbnails)
                         |            v                 ^
                         |       Read Replica           |
                         |                              |
                         +---- App Servers              |
                                                        |
                                                 Thumbnail Worker
                                                        ^
                                                        |
                                                    Job Queue
                                                        ^
                                                        |
                                                 App Servers
                                             (publish upload jobs)
```

The diagram represents the main logical components. Application servers coordinate requests, the primary database handles writes, the read replica serves eligible reads, and object storage holds image files. The job queue and thumbnail worker handle image processing asynchronously.

## 6. Architecture Components

### 1. DNS Service

DNS translates SnapShare's domain name into the appropriate service endpoint so users can reach the application.

### 2. Content Delivery Network (CDN)

The CDN caches and delivers frequently requested photos and thumbnails from locations closer to users, reducing latency and traffic to the origin infrastructure.

### 3. Load Balancer

The load balancer distributes incoming application requests across multiple application servers to prevent one server from becoming overloaded and to route requests away from unhealthy instances.

### 4. Application Servers

At least two application servers handle API requests, authenticate users, validate uploads, retrieve feed metadata, and coordinate database and object-storage operations.

### 5. Cache Layer

A cache such as Redis stores frequently accessed feed data and metadata, reducing repeated database queries and improving response times.

### 6. Primary Database

The primary relational database stores structured information such as users, photo metadata, captions, and relationships while handling database writes.

### 7. Read Replica

A read replica serves eligible database read queries, reducing the read workload on the primary database. Replication keeps it updated, although changes may not become visible immediately.

### 8. Object Storage

Object storage holds original photos and generated thumbnails, allowing image storage to scale independently of the relational database.

### 9. Job Queue

The job queue stores background-processing jobs, such as thumbnail-generation requests, until workers can process them. This prevents upload requests from having to wait for thumbnail processing to finish.

### 10. Thumbnail Worker

The thumbnail worker consumes jobs from the queue, retrieves original photos from object storage, generates smaller thumbnails, and saves the resulting files back to object storage.

## 7. Photo Upload Flow

1. **User submits a photo:** The user selects a photo and uploads it through the SnapShare client.

2. **Request routing:** DNS resolves the application endpoint, and the load balancer routes the API request to a healthy application server.

3. **Authentication and validation:** The application server verifies the user's identity and checks that the uploaded file meets the application's file-type, size, and authorization requirements.

4. **Store the original photo:** The original image is uploaded to object storage. For large uploads, the application can issue a secure, time-limited upload URL so the client can upload directly to storage.

5. **Save photo metadata:** The application records the photo ID, owner ID, caption, upload timestamp, and storage key in the primary database.

6. **Queue thumbnail processing:** The application publishes a thumbnail-generation job to the job queue. The job contains the photo ID and the information the worker needs to locate the original image.

7. **Respond to the user:** Once the required upload and metadata operations succeed and the job has been safely queued, the application returns a successful response without waiting for the thumbnail worker to finish.

8. **Process the queued job:** A thumbnail worker retrieves the job, reads the original photo from object storage, and generates the thumbnail.

9. **Store the thumbnail:** The worker saves the thumbnail in object storage and updates the photo's processing status if the application tracks that status.

10. **Make the photo available:** The thumbnail can be served through the CDN. The application refreshes or invalidates relevant feed-cache entries when necessary.

### How the queue avoids blocking uploads

The job queue separates the upload request from thumbnail generation. Instead of making the user wait for image resizing, the application places a job in the queue and returns a response after the necessary upload steps have succeeded.

Workers process jobs independently and can scale horizontally when the queue grows. If processing fails temporarily, the job can be retried without requiring the user to upload the original photo again.

The implementation should also handle failures between object storage, the database, and the queue. Retries, idempotent jobs, and reliable job publication help prevent duplicate processing and inconsistent records. For example, a transactional outbox can be used to coordinate database changes with reliable job publication.

## 8. Scaling Trade-offs

### Trade-off 1: Caching versus data freshness

Caching reduces database load and improves feed response times. However, cached feed data may become stale when users upload photos or update captions.

**Mitigation:** Use appropriate cache expiration times and invalidate or refresh affected cache entries after relevant updates. For requests that require the latest data, read from the primary database when appropriate.

### Trade-off 2: Read replicas versus consistency

Read replicas distribute database read traffic and reduce the workload on the primary database. However, replication lag can cause users to temporarily see outdated data after uploading a photo.

**Mitigation:** Route read-after-write operations to the primary database when immediate consistency is required. Use replicas for less time-sensitive feed queries.

### Trade-off 3: Asynchronous processing versus immediate availability

A job queue keeps upload requests responsive by moving thumbnail generation to background workers. However, a thumbnail may not be available immediately after the original photo has been uploaded.

**Mitigation:** Track thumbnail-processing status and display the original photo or a placeholder until the thumbnail is ready. Retry failed jobs and alert the team if the queue backlog grows beyond acceptable limits.

### Trade-off 4: Scalability versus operational complexity

Adding caches, replicas, queues, workers, and multiple application servers improves scalability but increases infrastructure costs, monitoring requirements, and the number of failure scenarios to manage.

**Mitigation:** Monitor request latency, error rates, queue depth, cache hit rates, database utilization, and storage growth. Scale individual components based on measured demand rather than increasing every component at the same rate.

## 9. Reliability and Single Points of Failure

The architecture should avoid depending on a single application server or worker. Multiple application servers behind a load balancer allow requests to continue if one server fails.

The primary database requires automated backups, monitoring, and a tested recovery procedure. High availability may require database failover to a suitable replica, with an explicit recovery-point and recovery-time objective.

The queue and background workers should support retries, idempotent processing, and dead-letter handling for jobs that repeatedly fail. Queue depth and processing delays should be monitored to detect backlogs.

Object storage should use suitable durability settings, access controls, and recovery policies. CDN and cache failures should not cause permanent data loss because the original images and authoritative metadata remain in their respective storage systems.

## 10. Conclusion

SnapShare has approximately 1 million daily active users, 1 million daily photo uploads, and 50 million daily feed views under the stated assumptions. This corresponds to about 11.6 uploads per second, 579 average feed views per second, and 2,894 peak feed views per second.

At the assumed image sizes, original photos and thumbnails require approximately **748.25 TB of additional storage per year**, before accounting for backups and other overhead.

A scalable solution combines a CDN, load balancer, multiple application servers, caching, a primary database with a read replica, object storage, a job queue, and thumbnail workers. This design separates image delivery, structured data, and background processing so each part can scale according to its workload.

The most important architectural decisions are to keep image binaries out of the relational database, optimize the read-heavy feed path, and process thumbnails asynchronously without making users wait for background work.
