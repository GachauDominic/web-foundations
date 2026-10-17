# TicketHub: Ticketing System Design

## Part 1: Requirements

### Functional requirements

TicketHub is a website where users browse concerts and events, select seats, purchase tickets, and view their orders.

The system must:

1. Allow users to register, log in, and manage their accounts.
2. Display upcoming events, including dates, venues, prices, and seat availability.
3. Allow users to view an event's seat map and current availability.
4. Temporarily hold available seats while a customer completes checkout.
5. Allow customers to pay for tickets and receive order confirmation.
6. Prevent two customers from purchasing the same seat.
7. Allow customers to view their purchased tickets and order history.
8. Automatically release expired seat holds.
9. Handle payment failures and retries without creating duplicate orders or charges.

### Non-functional requirements

- **Speed:** Event listings and seat maps should load quickly under normal traffic. During popular sales, customers should receive clear waiting-room feedback rather than encountering repeated timeouts.
- **Correctness:** Each seat can be sold only once. Seat inventory, order status, and payment status must remain consistent.
- **Fairness:** A virtual waiting room should control admission during high-demand sales. A documented queue policy, rate limits, and anti-bot measures should reduce unfair advantages from automated or repeated requests.
- **Availability:** Multiple application servers should allow the application to continue operating when an individual server fails.
- **Scalability:** The system must support normal browsing and sudden increases in requests during popular ticket releases.
- **Security:** Authentication, authorization, encrypted connections, secure payment-provider integration, and request validation must protect users and transactions.
- **Reliability:** Failed requests, payment callbacks, and background jobs must be safely retried without duplicating purchases or leaving seats permanently locked.

## Part 2: Capacity Estimates

### Normal daily traffic

Assumptions:

- Registered users: 2,000,000.
- Daily visitors: 50,000.
- Each visitor views 10 pages per day.
- Tickets sold: 5,000 per normal day.
- Seconds per day: 86,400.

**Daily page views**

50,000 × 10 = 500,000 page views per day.

**Average page views per second**

500,000 ÷ 86,400 = 5.79

Normal average traffic is approximately **5.8 page views per second**.

**Average ticket sales per second**

5,000 ÷ 86,400 = 0.058

Normal sales average approximately **0.058 tickets per second**, or one ticket every 17.3 seconds.

### Popular concert sale

Assumptions:

- Potential buyers: 200,000.
- Available seats: 20,000.
- Sale window: 10 minutes = 600 seconds.

**Average buyer-arrival rate**

200,000 ÷ 600 = 333.3

Approximately **333 potential buyers per second** arrive during the sale window, assuming arrivals are evenly distributed.

**Sales rate required to sell all seats in ten minutes**

20,000 ÷ 600 = 33.3

The platform must complete approximately **33 successful ticket sales per second** to sell all 20,000 seats within ten minutes.

**Competition per seat**

200,000 ÷ 20,000 = 10

There are **10 potential buyers for every available seat**.

### Normal traffic versus popular sale

| Metric                               |            Normal day |               Popular sale |
| ------------------------------------ | --------------------: | -------------------------: |
| Registered users                     |             2,000,000 |                  2,000,000 |
| Visitors or potential buyers         |        50,000 per day |      200,000 in 10 minutes |
| Average page views or buyer arrivals | 5.8 page views/second |  333 buyer arrivals/second |
| Ticket sales                         |         5,000 per day | Up to 20,000 in 10 minutes |
| Average sales rate needed            |  0.058 tickets/second |        33.3 tickets/second |

The popular sale creates a concentrated workload. Its average buyer-arrival rate is approximately 57 times the normal average page-view rate, although these are different metrics and should not be treated as equivalent API request rates.

Each buyer may issue several requests to browse events, view seats, create a hold, and pay. Therefore, actual API traffic can be much higher than the buyer-arrival rate. A waiting room and load testing are necessary to manage the burst.

## Part 3: API Design

The API follows REST principles and uses JSON request and response bodies. Endpoints that modify seat inventory or create orders require authentication.

| Method | Endpoint                       | Purpose                                   | Expected status codes |
| ------ | ------------------------------ | ----------------------------------------- | --------------------- |
| GET    | `/api/events`                  | Browse events with pagination and filters | 200                   |
| GET    | `/api/events/:eventId`         | View event details                        | 200, 404              |
| GET    | `/api/events/:eventId/seats`   | View seats and their availability         | 200, 404              |
| POST   | `/api/seat-holds`              | Temporarily hold available seats          | 201, 409              |
| DELETE | `/api/seat-holds/:holdId`      | Release an active hold                    | 200, 404, 409         |
| POST   | `/api/orders`                  | Create an order from a valid hold         | 201, 409              |
| POST   | `/api/orders/:orderId/payment` | Initiate or confirm payment processing    | 200, 202, 402         |
| GET    | `/api/me/tickets`              | View the authenticated user's tickets     | 200                   |
| GET    | `/api/orders/:orderId`         | View an order's status                    | 200, 403, 404         |

### Example: Browse events

```http
GET /api/events
```

Example response:

```json
{
  "events": [
    {
      "eventId": "evt-101",
      "name": "Summer Music Festival",
      "venue": "City Arena",
      "date": "2027-06-20",
      "availableSeats": 1200
    }
  ],
  "page": 1,
  "pageSize": 20
}
```

### Example: Hold seats

```http
POST /api/seat-holds
Content-Type: application/json
Authorization: Bearer <token>
Idempotency-Key: 7d52f1a8-unique-request-id
```

Request body:

```json
{
  "eventId": "evt-101",
  "seatIds": ["seat-A12", "seat-A13"]
}
```

Example success response:

```json
{
  "holdId": "hold-501",
  "status": "active",
  "seatIds": ["seat-A12", "seat-A13"],
  "expiresAt": "2027-06-20T14:05:00Z"
}
```

If any requested seat is already held or sold, the server returns `409 Conflict` and does not create a partial hold.

### Example: Seat unavailable

```json
{
  "error": {
    "code": "SEAT_UNAVAILABLE",
    "message": "One or more requested seats are no longer available."
  }
}
```

Idempotency keys should also be used for order creation and payment operations. This ensures that retrying a request after a network timeout does not create duplicate orders or charges.

## Part 4: Data Model and Database Schemas

TicketHub uses PostgreSQL because ticket sales require relational integrity, atomic updates, and transactional concurrency control.

The four core tables are `users`, `events`, `seats`, and `orders`. Supporting tables `order_items`, `payments`, and `seat_holds` represent purchased seats, payment attempts, and temporary reservations.

### 4.1 PostgreSQL schema

The following SQL defines the tables and their relationships. Run it in the order shown because foreign keys depend on earlier tables.

```sql
CREATE TABLE users (
    user_id UUID PRIMARY KEY,
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE events (
    event_id UUID PRIMARY KEY,
    name VARCHAR(200) NOT NULL,
    venue VARCHAR(200) NOT NULL,
    event_date TIMESTAMPTZ NOT NULL,
    status VARCHAR(20) NOT NULL
        CHECK (status IN ('scheduled', 'on_sale', 'sold_out', 'cancelled'))
);

CREATE TABLE orders (
    order_id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(user_id),
    status VARCHAR(20) NOT NULL
        CHECK (status IN (
            'pending', 'paid', 'failed', 'cancelled', 'expired'
        )),
    total_amount NUMERIC(10, 2) NOT NULL
        CHECK (total_amount >= 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE seats (
    seat_id UUID PRIMARY KEY,
    event_id UUID NOT NULL REFERENCES events(event_id),
    section VARCHAR(50) NOT NULL,
    seat_number VARCHAR(20) NOT NULL,
    price NUMERIC(10, 2) NOT NULL CHECK (price >= 0),
    status VARCHAR(20) NOT NULL DEFAULT 'available'
        CHECK (status IN ('available', 'held', 'sold')),
    held_by_user_id UUID REFERENCES users(user_id),
    hold_expires_at TIMESTAMPTZ,
    sold_order_id UUID REFERENCES orders(order_id),

    CONSTRAINT unique_event_seat
        UNIQUE (event_id, section, seat_number),

    CONSTRAINT valid_hold_state CHECK (
        (status = 'held'
            AND held_by_user_id IS NOT NULL
            AND hold_expires_at IS NOT NULL)
        OR
        (status <> 'held'
            AND held_by_user_id IS NULL
            AND hold_expires_at IS NULL)
    ),

    CONSTRAINT valid_sold_state CHECK (
        (status = 'sold' AND sold_order_id IS NOT NULL)
        OR
        (status <> 'sold' AND sold_order_id IS NULL)
    )
);

CREATE TABLE seat_holds (
    hold_id UUID PRIMARY KEY,
    seat_id UUID NOT NULL REFERENCES seats(seat_id),
    user_id UUID NOT NULL REFERENCES users(user_id),
    expires_at TIMESTAMPTZ NOT NULL,
    status VARCHAR(20) NOT NULL
        CHECK (status IN ('active', 'converted', 'released', 'expired')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE order_items (
    order_item_id UUID PRIMARY KEY,
    order_id UUID NOT NULL REFERENCES orders(order_id),
    seat_id UUID NOT NULL UNIQUE REFERENCES seats(seat_id),
    price_at_purchase NUMERIC(10, 2) NOT NULL
        CHECK (price_at_purchase >= 0)
);

CREATE TABLE payments (
    payment_id UUID PRIMARY KEY,
    order_id UUID NOT NULL REFERENCES orders(order_id),
    provider_reference VARCHAR(255) UNIQUE,
    amount NUMERIC(10, 2) NOT NULL CHECK (amount >= 0),
    status VARCHAR(20) NOT NULL
        CHECK (status IN ('pending', 'successful', 'failed', 'refunded')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_events_date
    ON events(event_date);

CREATE INDEX idx_seats_event_status
    ON seats(event_id, status);

CREATE INDEX idx_orders_user_created
    ON orders(user_id, created_at DESC);

CREATE INDEX idx_active_holds_expiry
    ON seat_holds(expires_at)
    WHERE status = 'active';
```

**Schema note:** The `order_items.seat_id` unique constraint prevents a seat from being assigned to more than one order item. This schema treats a sold seat as permanently sold. If the business later supports cancellations and resale, the constraint and historical purchase model must be revised carefully so that only one active sale can exist at a time.

### 4.2 Table purposes

- **users:** Stores customer accounts and unique email addresses.
- **events:** Stores event names, venues, dates, and sale status.
- **seats:** Stores the inventory for each event, including seat identity, price, availability, hold owner, expiry time, and sale order.
- **orders:** Records a customer's purchase and its overall status.
- **order_items:** Connects orders to specific seats and preserves the price at purchase.
- **payments:** Stores payment-provider references, amounts, and payment status.
- **seat_holds:** Records temporary reservation attempts and their expiry or release status.

### 4.3 Relationships

- One user can create many orders: `users 1 — many orders`.
- One event has many seats: `events 1 — many seats`.
- One order contains one or more order items: `orders 1 — many order_items`.
- Each order item refers to one seat.
- One order can have multiple payment attempts or records: `orders 1 — many payments`.
- One user can create multiple seat holds.
- A seat can have historical hold records, but only one active hold can control its current inventory state.

Foreign keys prevent references to nonexistent users, events, seats, and orders. Unique constraints prevent duplicate emails, duplicate seat labels within an event, duplicate seat assignments to order items, and duplicate provider references.

## Part 5: Preventing Double-Booking with Transactions

The application must not rely on a browser's seat map or an initial availability check to guarantee a seat. Two customers can view the same seat as available at nearly the same time.

The database must make the final decision through an atomic conditional update or row locking inside a transaction.

### 5.1 Atomic seat hold

The following PostgreSQL statement acquires a seat only if it is available or its previous hold has expired:

```sql
UPDATE seats
SET
    status = 'held',
    held_by_user_id = :user_id,
    hold_expires_at = :expires_at
WHERE seat_id = :seat_id
  AND (
      status = 'available'
      OR (
          status = 'held'
          AND hold_expires_at <= CURRENT_TIMESTAMP
      )
  )
RETURNING seat_id;
```

The application checks the number of returned rows:

- **One row returned:** The seat has been successfully held by this transaction.
- **No row returned:** The seat is held by another customer or already sold; return `409 Conflict`.

PostgreSQL serializes conflicting updates to the same row. If two customers attempt to acquire the same seat concurrently, only one can successfully change the seat from an eligible state to `held`. The other update re-evaluates the row after waiting and fails its condition if the seat is no longer eligible.

### 5.2 Transaction for multiple seats

When a customer selects several seats, the application should acquire all of them in one transaction. If any seat is unavailable, roll back the transaction so the customer does not retain only some of the requested seats.

Conceptual application transaction:

```sql
BEGIN;

-- Repeat the conditional update for each requested seat.
-- If any update returns no row, ROLLBACK and return 409 Conflict.

-- Insert one seat_holds record for each successfully held seat.
-- Use unique hold IDs and the same expiry time.

COMMIT;
```

For a group of seats, acquire them in a consistent order (such as ascending seat ID) to reduce deadlock risk. If a deadlock occurs, the application should safely retry the entire transaction.

The seat updates and corresponding `seat_holds` inserts must commit together. If the transaction rolls back, none of those holds should remain.

### 5.3 Converting a hold into a purchase

The customer checks out while the hold is valid. The application verifies that each seat is still held by that customer and that the hold has not expired.

The final seat transition to sold must be conditional and transactional. For example, after payment has been verified:

```sql
BEGIN;

UPDATE seats
SET
    status = 'sold',
    sold_order_id = :order_id,
    held_by_user_id = NULL,
    hold_expires_at = NULL
WHERE seat_id = :seat_id
  AND status = 'held'
  AND held_by_user_id = :user_id
  AND hold_expires_at > CURRENT_TIMESTAMP
RETURNING seat_id;

-- The application must confirm that exactly one row was returned.
-- If not, ROLLBACK: the hold is no longer valid.

-- Insert the order_items record and update the order status
-- in this same transaction.

COMMIT;
```

This is conceptual SQL: the application must verify that the update succeeded before inserting the order item or committing. The transaction must also ensure that the order belongs to the same user and that its payment has been verified. A unique `order_items.seat_id` constraint provides an additional database safeguard.

### 5.4 Payment processing and external failures

Do not keep a database transaction open while waiting for a payment provider's network response. External payment requests can be slow or time out.

Instead:

1. Create a pending order for the valid seat hold.
2. Initiate payment using an idempotency key.
3. Receive and verify the payment provider's response or signed callback.
4. Finalize the order and change held seats to sold in a short database transaction.
5. If payment fails or the hold expires, follow a defined cancellation and release policy.

The workflow must address the possibility that payment succeeds just as a hold expires. The system should define a consistent policy for this race, reconcile payment status, and issue refunds when necessary rather than silently creating an inconsistent sale.

### 5.5 Releasing expired holds

A worker can periodically locate expired holds and attempt to release the associated seats. Release operations must be conditional, so a cleanup task cannot make a seat available after another transaction has re-held or sold it.

For example:

```sql
UPDATE seats
SET
    status = 'available',
    held_by_user_id = NULL,
    hold_expires_at = NULL
WHERE seat_id = :seat_id
  AND status = 'held'
  AND hold_expires_at <= CURRENT_TIMESTAMP;
```

The associated `seat_holds` record should be updated in the same transaction. If a competing transaction has already changed the seat, this update will not release it.

**Result:** The database is the authoritative source for seat inventory. Atomic updates, transactions, foreign keys, and unique constraints prevent two customers from successfully purchasing the same seat, even when requests arrive simultaneously.

## Part 6: Architecture and Scalability

### 6.1 Architecture diagram

```text
                         Customers
                             |
                             v
                         DNS Service
                             |
                             v
                      CDN / Static Assets
                             |
                             v
                    Virtual Waiting Room
                             |
                             v
                        Load Balancer
                             |
                 +-----------+-----------+
                 |                       |
                 v                       v
            App Server 1            App Server 2
                 |                       |
                 +-----------+-----------+
                             |
             +---------------+----------------+
             |               |                |
             v               v                v
         Redis Cache    Primary Database   Payment Provider
                            PostgreSQL          |
                 |              |               |
                 |              v               |
                 |         Read Replica          |
                 |                               |
                 +---------- App Servers <-------+
                             |
                             v
                          Job Queue
                             |
                             v
                     Background Workers
               (notifications, hold expiry,
                  payment reconciliation)
```

### 6.2 Component explanations

**DNS service:** Resolves the TicketHub domain to the service endpoint.

**CDN and static assets:** Serves cached event posters, JavaScript, CSS, and other static resources close to users, reducing requests reaching the application.

**Virtual waiting room:** Controls admission during popular sales, smooths bursts, and applies a defined queue policy to promote fair access.

**Load balancer:** Distributes incoming requests across healthy application-server instances.

**Application servers:** Handle authentication, event browsing, seat holds, order creation, and payment coordination. Multiple instances support horizontal scaling.

**Redis cache:** Caches event details and suitable read-heavy data. It is not the authoritative source of seat ownership or availability.

**Primary PostgreSQL database:** Stores users, events, seat inventory, holds, orders, order items, and payment records. It enforces the transactions and constraints required for correct seat sales.

**Read replica:** Serves eligible read-only queries, such as event browsing, to reduce primary database load. Replication lag means it must not make authoritative seat-hold or purchase decisions.

**Payment provider:** Processes payments and returns transaction outcomes. TicketHub verifies responses and handles callbacks idempotently rather than storing raw card details.

**Job queue:** Stores asynchronous tasks such as sending notifications, releasing expired holds, and reconciling payment workflows.

**Background workers:** Process queued tasks independently of user-facing requests. They use retries, monitoring, and idempotent operations to recover from temporary failures.

### 6.3 How the architecture handles a popular sale

- The waiting room controls admission and reduces the initial request burst.
- Multiple application servers scale horizontally behind the load balancer.
- The CDN serves static content without consuming application-server capacity.
- Redis reduces repeated event-detail queries.
- The read replica serves eligible browsing requests, while the primary database handles authoritative seat updates.
- Short database transactions reduce row-lock duration and improve concurrency.
- Rate limits, purchase limits, and anti-bot controls reduce abuse.
- Background workers handle notifications and reconciliation outside the critical checkout path.
- Connection pooling, bounded queues, timeouts, and load tests help prevent resource exhaustion.

A waiting room alone does not guarantee capacity. The database, payment integration, and full checkout flow must be load-tested under realistic concurrent demand.

## Part 7: System Trade-offs

### Trade-off 1: Consistency versus read performance

Reading all data from the primary database gives fresher results but increases database load. Caches and read replicas improve browsing performance but may serve stale information.

**Decision:** Use caches and replicas for event browsing and other tolerant reads. Use transactional operations on the primary database for holds, purchases, and authoritative order changes.

### Trade-off 2: Fairness versus throughput

A virtual waiting room smooths bursts and provides an orderly admission policy, but adds waiting time and may reduce the rate at which customers reach checkout.

**Decision:** Apply a transparent queue policy, communicate waiting status, and tune the admission rate through load testing. Rate limits and anti-bot protections should apply consistently.

### Trade-off 3: Hold duration versus inventory availability

Long holds give customers more time to complete checkout but keep seats unavailable to other buyers. Short holds improve inventory turnover but may penalize customers experiencing payment delays.

**Decision:** Use a clearly communicated hold duration, release expired holds safely, and define how payment delays are handled.

### Trade-off 4: Synchronous versus asynchronous payment workflows

Waiting for the payment provider during checkout simplifies immediate confirmation but can tie up application resources. Asynchronous confirmation improves resilience but can leave orders pending temporarily.

**Decision:** Use explicit order and payment states, idempotency keys, verified callbacks, and reconciliation. Never assume a timeout means payment failed; reconcile uncertain outcomes before releasing or reselling inventory.

## Conclusion

TicketHub must support 50,000 normal daily visitors and a popular sale where 200,000 potential buyers compete for 20,000 seats in ten minutes.

The design combines a waiting room, horizontally scaled application servers, caching, PostgreSQL, a read replica, a payment provider, and background workers.

Most importantly, seat ownership is controlled by atomic conditional updates and database transactions rather than by the browser or cache. This prevents double-booking under concurrent requests while the waiting room and scalable architecture help maintain performance and fairness during high demand.
