# TicketHub: Ticketing System Design

## Part 1: Requirements

### Functional requirements

TicketHub is a website where users browse events, select seats, purchase tickets, and view their orders.

The system must:

1. Allow users to register, log in, and manage their accounts.
2. Display upcoming concerts and events, including dates, venues, prices, and available seats.
3. Allow users to view a seat map and check seat availability.
4. Allow users to temporarily hold available seats while completing checkout.
5. Allow users to pay for tickets and receive order confirmation.
6. Prevent two users from purchasing the same seat.
7. Allow users to view their purchased tickets and order history.
8. Release expired seat holds so other customers can purchase those seats.

### Non-functional requirements

**Speed:** Event pages and seat maps should load quickly under normal traffic. During a popular sale, the system should remain responsive and provide clear waiting or queue status rather than becoming unavailable.

**Correctness:** A seat must never be sold to more than one customer. Payment status, order status, and seat inventory must remain consistent, including when requests fail or are retried.

**Fairness:** During a high-demand sale, customers should enter through a controlled virtual waiting room. Requests should be processed according to the queue policy, with protections against automated purchasing and repeated requests that could unfairly increase a customer's position.

**Availability:** The system should tolerate individual application-server failures and recover from temporary payment-provider or worker failures.

**Security:** Authentication, authorization, encrypted connections, rate limiting, and payment-provider verification must protect customer accounts and purchases.

**Scalability:** The system must handle ordinary browsing traffic and sudden bursts of requests when popular concerts go on sale.

**Reliability:** Failed payments, expired holds, and interrupted requests must not leave seats permanently unavailable or create duplicate orders.

## Part 2: Capacity Estimates

### Normal daily traffic

Assumptions:

- Registered users: 2,000,000.
- Daily visitors: 50,000.
- Each visitor views 10 pages per day.
- Tickets sold per day: 5,000.
- One day contains 86,400 seconds.

**Daily page views**

50,000 visitors × 10 pages = 500,000 page views per day.

**Average page views per second**

500,000 ÷ 86,400 = 5.79

Average traffic is approximately **5.8 page views per second**.

**Average ticket sales per second**

5,000 ÷ 86,400 = 0.058

Average sales are approximately **0.058 tickets per second**, or one ticket every 17.3 seconds on average.

These are daily averages; actual traffic will fluctuate throughout the day.

### Popular concert sale

Assumptions:

- People attempting to buy tickets: 200,000.
- Seats available: 20,000.
- Time window: 10 minutes, or 600 seconds.

**Average arrival rate**

200,000 ÷ 600 = 333.3

Approximately **333 potential buyers arrive per second** during the sale window, assuming arrivals are spread evenly. In practice, the initial burst may be much higher.

**Maximum ticket sales rate needed to sell all seats within 10 minutes**

20,000 ÷ 600 = 33.3

The system must complete approximately **33 successful ticket sales per second** on average to sell all seats within the 10-minute window.

**Competition for seats**

200,000 people ÷ 20,000 seats = 10

There are approximately **10 potential buyers for every available seat**.

### Comparison

| Metric                                |                       Normal day |                          Popular concert sale |
| ------------------------------------- | -------------------------------: | --------------------------------------------: |
| Registered users                      |                        2,000,000 |                                     2,000,000 |
| People visiting / attempting purchase |          50,000 visitors per day |                  200,000 people in 10 minutes |
| Page views or arrival rate            | 5.8 page views/second on average |          333 buyer arrivals/second on average |
| Tickets sold                          |                    5,000 per day |                    Up to 20,000 in 10 minutes |
| Average sales rate                    |             0.058 tickets/second | 33.3 tickets/second to sell out in 10 minutes |

The popular sale creates a much more concentrated workload than a normal day. Its average buyer-arrival rate is about 57 times the normal day's average page-view rate, although these are different types of activity and should not be treated as equivalent API request rates.

Each buyer may generate multiple API requests, so actual request volume can be considerably higher than the buyer-arrival rate. The architecture should be designed for bursts rather than relying only on daily averages.

## Part 3: API Design

The API uses REST principles and JSON request and response bodies. Endpoints that change inventory or create orders require authentication.

| Method | Endpoint                       | Description                                                  | Expected responses                         |
| ------ | ------------------------------ | ------------------------------------------------------------ | ------------------------------------------ |
| GET    | `/api/events`                  | List upcoming events with pagination and filters             | 200 OK                                     |
| GET    | `/api/events/:eventId`         | Retrieve event details, venue, date, and pricing             | 200 OK, 404 Not Found                      |
| GET    | `/api/events/:eventId/seats`   | Retrieve seat numbers, prices, and availability              | 200 OK, 404 Not Found                      |
| POST   | `/api/seat-holds`              | Temporarily hold one or more available seats                 | 201 Created, 409 Conflict                  |
| DELETE | `/api/seat-holds/:holdId`      | Release a customer's active seat hold                        | 200 OK, 404 Not Found, 409 Conflict        |
| POST   | `/api/orders`                  | Create an order from a valid seat hold and initiate checkout | 201 Created, 409 Conflict                  |
| POST   | `/api/orders/:orderId/payment` | Initiate or confirm payment processing                       | 200 OK, 202 Accepted, 402 Payment Required |
| GET    | `/api/me/tickets`              | List the authenticated user's purchased tickets              | 200 OK                                     |
| GET    | `/api/orders/:orderId`         | Retrieve the authenticated user's order status               | 200 OK, 403 Forbidden, 404 Not Found       |

### Example: Browse events

Request:

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

Request:

```http
POST /api/seat-holds
Content-Type: application/json
Authorization: Bearer <token>
Idempotency-Key: 7d52f1a8-unique-request-id
```

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

If a requested seat has already been held or sold, the API returns `409 Conflict` instead of confirming the hold.

### Example: Error response

```json
{
  "error": {
    "code": "SEAT_UNAVAILABLE",
    "message": "One or more requested seats are no longer available."
  }
}
```

The API should use consistent error codes and avoid exposing sensitive internal details. Idempotency keys should be used for order creation and payment operations so that retries do not create duplicate purchases or charges.

## Part 4: Data Model

TicketHub uses a relational database such as PostgreSQL because orders, seats, payments, and users require strong relationships and transactional consistency.

The core model contains six tables: `users`, `events`, `seats`, `orders`, `order_items`, and `payments`. A separate `seat_holds` table records temporary reservations.

### Table 1: users

Stores customer accounts.

| Column        | Type         | Constraints      |
| ------------- | ------------ | ---------------- |
| user_id       | UUID         | Primary key      |
| email         | VARCHAR(255) | NOT NULL, UNIQUE |
| password_hash | TEXT         | NOT NULL         |
| created_at    | TIMESTAMPTZ  | NOT NULL         |

### Table 2: events

Stores concert and event information.

| Column     | Type         | Constraints |
| ---------- | ------------ | ----------- |
| event_id   | UUID         | Primary key |
| name       | VARCHAR(200) | NOT NULL    |
| venue      | VARCHAR(200) | NOT NULL    |
| event_date | TIMESTAMPTZ  | NOT NULL    |
| status     | VARCHAR(20)  | NOT NULL    |

### Table 3: seats

Stores the seats available for each event.

| Column          | Type          | Constraints                    |
| --------------- | ------------- | ------------------------------ |
| seat_id         | UUID          | Primary key                    |
| event_id        | UUID          | Foreign key to events          |
| section         | VARCHAR(50)   | NOT NULL                       |
| seat_number     | VARCHAR(20)   | NOT NULL                       |
| price           | NUMERIC(10,2) | NOT NULL, CHECK price >= 0     |
| status          | VARCHAR(20)   | NOT NULL                       |
| held_by_user_id | UUID          | Nullable foreign key to users  |
| hold_expires_at | TIMESTAMPTZ   | Nullable                       |
| sold_order_id   | UUID          | Nullable foreign key to orders |

A unique constraint on `(event_id, section, seat_number)` prevents duplicate seat records for the same event.

The `status` field can contain values such as `available`, `held`, or `sold`. State transitions must be controlled by transactional application logic.

### Table 4: orders

Stores customer purchase attempts and their status.

| Column       | Type          | Constraints                       |
| ------------ | ------------- | --------------------------------- |
| order_id     | UUID          | Primary key                       |
| user_id      | UUID          | Foreign key to users              |
| status       | VARCHAR(20)   | NOT NULL                          |
| total_amount | NUMERIC(10,2) | NOT NULL, CHECK total_amount >= 0 |
| created_at   | TIMESTAMPTZ   | NOT NULL                          |

Order statuses may include `pending`, `paid`, `failed`, and `cancelled`.

### Table 5: order_items

Stores the seats included in each order.

| Column            | Type          | Constraints                            |
| ----------------- | ------------- | -------------------------------------- |
| order_item_id     | UUID          | Primary key                            |
| order_id          | UUID          | Foreign key to orders                  |
| seat_id           | UUID          | Foreign key to seats                   |
| price_at_purchase | NUMERIC(10,2) | NOT NULL, CHECK price_at_purchase >= 0 |

Each order item links one seat to an order. A unique constraint on `seat_id` in `order_items` can provide an additional safeguard against assigning a seat to multiple order items, provided a sold seat's order-item record is retained permanently and cancellation or refund workflows do not delete or reuse it. The seat's transactional state remains the primary inventory control.

### Table 6: payments

Stores payment-provider references and payment status.

| Column             | Type          | Constraints                 |
| ------------------ | ------------- | --------------------------- |
| payment_id         | UUID          | Primary key                 |
| order_id           | UUID          | Foreign key to orders       |
| provider_reference | VARCHAR(255)  | UNIQUE                      |
| amount             | NUMERIC(10,2) | NOT NULL, CHECK amount >= 0 |
| status             | VARCHAR(20)   | NOT NULL                    |
| created_at         | TIMESTAMPTZ   | NOT NULL                    |

Payment statuses may include `pending`, `successful`, and `failed`. The application should verify payment results with the provider and handle payment notifications idempotently.

### Table 7: seat_holds

Stores temporary seat reservations.

| Column     | Type        | Constraints          |
| ---------- | ----------- | -------------------- |
| hold_id    | UUID        | Primary key          |
| seat_id    | UUID        | Foreign key to seats |
| user_id    | UUID        | Foreign key to users |
| expires_at | TIMESTAMPTZ | NOT NULL             |
| status     | VARCHAR(20) | NOT NULL             |

A hold associates a user with a seat temporarily. The application must prevent multiple active holds for the same seat through transactional updates to the seat record or an appropriate database constraint. Expired holds must be eligible for release.

### Relationships

- One user can place many orders: `users 1 — many orders`.
- One event can have many seats: `events 1 — many seats`.
- One order can contain multiple order items: `orders 1 — many order_items`.
- Each order item refers to one seat: `seats 1 — many historical order_items` at the schema level, though a seat must not be sold twice.
- One order can have payment records or payment attempts: `orders 1 — many payments`.
- One user can create many seat holds: `users 1 — many seat_holds`.
- One seat can have multiple historical holds, but only one active hold at a time.

Foreign keys enforce referential integrity. Check constraints validate numeric values, while unique constraints prevent duplicate emails, duplicate seat labels within an event, and duplicate payment-provider references.

## Part 5: Preventing Double-Booking

The most important correctness requirement is that two customers must never successfully purchase the same seat.

A simple application-side check is insufficient. Two requests could both read a seat as available before either request updates it. The system must use atomic database operations and transactions to make the decision authoritative.

### Step 1: Atomically acquire the seat

When a user requests a seat hold, the application starts a database transaction and locks the requested seat rows using `SELECT ... FOR UPDATE`, or uses an equivalent atomic conditional update.

Conceptual SQL for one seat:

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

If the statement returns a row, the hold was acquired. If it returns no row, another customer already holds or purchased the seat, so the application returns `409 Conflict`.

For a request containing multiple seats, all seats must be acquired within one transaction. If any requested seat cannot be acquired, the transaction rolls back so the user does not end up with only part of the requested group.

### Step 2: Commit the hold

The application records the hold and its expiration time in the same transaction as the seat update. The transaction commits only if the required seats are successfully acquired.

This prevents two concurrent transactions from both successfully changing the same seat from available to held.

### Step 3: Create the order and process payment

The user checks out before the hold expires. The application verifies that the hold belongs to the user and remains valid, then creates an order and its order items.

Payment should be processed through a payment provider. The database transaction should not remain open while waiting for a slow external payment request. Instead, the application uses a controlled payment workflow, tracks payment status, and finalizes the order only after verifying the payment result.

The transition from held to sold must be conditional and transactional. If the hold has expired or no longer belongs to the customer, the purchase must not succeed.

### Step 4: Release expired holds

A scheduled worker or a request-time cleanup process finds expired holds and returns their seats to `available` if the seats are still held under those expired holds.

The update must be conditional so that cleanup cannot release a seat that has already been sold or re-held by another customer.

### Step 5: Add database constraints and idempotency

The system uses foreign keys, unique constraints, and valid state transitions as additional protection against inconsistent data. A unique constraint on an order item's `seat_id`, with retained records for sold seats, can prevent a second order item from being created for that seat.

Idempotency keys prevent client retries from creating duplicate orders or initiating duplicate payment operations. Payment callbacks must also be verified and processed idempotently.

**Result:** Seat availability is decided by the database through atomic operations, not by a potentially stale seat map in the browser. The seat map can show a seat as available just before another customer acquires it, but only one concurrent transaction can successfully hold that seat.

## Part 6: Architecture

### Architecture diagram

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
                 +---------+---------+
                 |                   |
                 v                   v
            App Server 1        App Server 2
                 |                   |
                 +---------+---------+
                           |
              +------------+------------+
              |            |            |
              v            v            v
          Redis Cache  Primary DB   Payment Provider
              |         (PostgreSQL)        |
              |            |                |
              |            v                |
              |        Read Replica          |
              |                             |
              +---- App Servers <------------+
                           |
                           v
                      Job Queue
                           |
                           v
                    Background Workers
                (hold expiry, notifications,
                   order reconciliation)
```

### Component explanations

**1. DNS service:** Resolves the TicketHub domain to the appropriate entry point.

**2. CDN and static assets:** Delivers cached images, event posters, JavaScript, CSS, and other static resources without sending every request to the application servers.

**3. Virtual waiting room:** Controls admission during popular sales, limits the rate at which customers reach the seat-holding and checkout services, and applies a defined queue policy to promote fair access.

**4. Load balancer:** Distributes admitted application requests across healthy application-server instances.

**5. Application servers:** Handle authentication, event browsing, seat-map requests, seat holds, order creation, and payment coordination. Multiple instances allow horizontal scaling.

**6. Redis cache:** Caches event details and other suitable read-heavy data. It may help reduce database load, but it must not be the authoritative source of seat ownership or availability.

**7. Primary PostgreSQL database:** Stores authoritative users, events, seat inventory, holds, orders, order items, and payment records. Transactions, row locking, and constraints enforce seat correctness.

**8. Read replica:** Handles eligible read-only queries such as event browsing. It reduces load on the primary database but may lag behind recent writes. Seat-hold and purchase decisions must use the primary database.

**9. Payment provider:** Processes payment details and reports transaction outcomes. TicketHub verifies provider responses and handles callbacks idempotently. Sensitive card details should not be stored directly by TicketHub.

**10. Job queue:** Holds asynchronous work such as notifications, hold-expiry tasks, and order reconciliation jobs. This keeps nonessential processing out of the critical request path.

**11. Background workers:** Process queued jobs, send order confirmations, release eligible expired holds, and reconcile interrupted payment workflows. Workers use retries and idempotent operations to handle failures safely.

### How the architecture survives a big sale

- The waiting room limits the rate of incoming purchase traffic and smooths the initial burst.
- Multiple application servers scale horizontally behind the load balancer.
- The CDN serves static content without consuming application-server capacity.
- Cached event details reduce repeated read queries.
- The read replica serves eligible browsing traffic while the primary database handles authoritative seat changes.
- Short, focused database transactions minimize the time seat rows remain locked.
- Rate limits and purchase limits reduce abuse and automated buying.
- The queue moves notifications and other noncritical tasks away from the seat-hold and checkout request paths.
- Monitoring tracks queue length, database connections, transaction conflicts, payment failures, and request latency.

The system should also use connection pooling, bounded request queues, database timeouts, and load testing before a major sale. A waiting room alone cannot guarantee capacity; the database and payment integration must be tested at the expected concurrency.

## Part 7: System Trade-offs

### Trade-off 1: Strict consistency versus read performance

Using the primary database for every read provides fresher data but increases its workload during a sale. Using a read replica and cache improves browsing performance, but their data may be stale.

**Decision:** Use caches and replicas for event browsing and other tolerant reads. Always use transactional operations on the primary database for seat holds, sales, and authoritative order changes.

### Trade-off 2: Fairness versus maximum throughput

A virtual waiting room can control bursts and provide an orderly admission policy, but it adds waiting time and may limit how quickly customers reach checkout.

**Decision:** Use a transparent queue policy, communicate expected waiting status, and tune the admission rate using load tests. Apply rate limits and anti-bot measures consistently rather than allowing users to gain an advantage through repeated requests.

### Trade-off 3: Longer seat holds versus seat availability

Long holds give customers more time to complete checkout, but seats remain unavailable to other customers for longer. Short holds improve inventory turnover but can penalize customers experiencing payment delays.

**Decision:** Use a clearly communicated hold duration, release expired holds safely, and provide a controlled checkout process. Do not extend holds indefinitely without a defined policy.

### Trade-off 4: Synchronous payment processing versus asynchronous workflows

Waiting for a payment provider during the checkout request makes it easier to return an immediate outcome, but a slow provider can tie up application capacity. Asynchronous payment confirmation improves resilience but means some orders remain pending temporarily.

**Decision:** Track explicit order and payment states, use idempotency keys, and reconcile uncertain payment outcomes. A seat should not be sold to another user merely because a payment response is delayed; the system must apply a defined timeout and compensation policy.

## Conclusion

TicketHub must handle 50,000 normal daily visitors and a concentrated sale in which 200,000 people compete for 20,000 seats in ten minutes.

The design combines a waiting room, horizontally scaled application servers, caching, a relational database, read replicas, a payment provider, and background workers. Most importantly, the database—not the browser or cache—controls seat ownership through transactions, atomic conditional updates, and constraints.

This approach balances performance and fairness during high demand while protecting the correctness of seat inventory, orders, and payments.
