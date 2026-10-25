# TicketHub System Design Document

## 1. Requirements

### Functional Requirements

- **Event Browsing & Discovery:** Users can view a list of upcoming concerts and events with details such as date, venue, and descriptions.
- **Seat Map Inspection:** Users can view a real-time seat availability map for a selected event.
- **Temporary Seat Reservation (Hold):** Users can temporarily lock selected seats for a limited time (e.g., 10 minutes) while completing payment.
- **Checkout & Payment Processing:** Users can securely submit payment information to finalize their ticket purchase.
- **Ticket Management:** Users can view their purchased tickets and order history.

### Non-Functional Requirements

- **Correctness:** Absolute data integrity—under no circumstances can two users successfully purchase or hold the exact same seat.
- **Fairness:** A structured queuing mechanism during high-demand sales to prevent bot swarms and ensure fair first-come, first-served access.
- **Speed & Low Latency:** Sub-second response times for standard browsing and reliable queue-managed responses during flash sales.

---

## 2. Traffic Estimates

### Baseline Normal Traffic

- **Registered Users:** 2,000,000
- **Daily Active Visitors:** 50,000 visitors/day
- **Page Views:** 10 pages per visitor $\rightarrow$ 500,000 page views per day.
- **Average QPS (Queries Per Second):**
  $$\frac{500,000 \text{ views}}{86,400 \text{ seconds}} \approx 5.8 \text{ QPS}$$
- **Daily Ticket Sales:** 5,000 tickets sold/day.

### Big Sale Peak Traffic

- **Flash Sale Scenario:** 200,000 users attempting to buy 20,000 seats within the first 10 minutes (600 seconds).
- **Average Peak QPS:**
  $$\frac{200,000 \text{ users}}{600 \text{ seconds}} \approx 333 \text{ requests/sec}$$
- **Burst Peak QPS:** Spikes can easily reach **3,000 to 5,000+ QPS** during the exact second tickets go on sale due to concurrent client refreshes and automated scripts.
- **Comparison:** Peak QPS is roughly **500x to 800x** higher than normal baseline traffic, requiring deliberate traffic shaping and queueing architecture.

---

## 3. API Design

### 1. Browse Events

- **Endpoint:** `GET /api/v1/events`
- **Query Parameters:** `page`, `limit`, `category`
- **Response:** List of upcoming events with metadata.

### 2. View Seat Availability

- **Endpoint:** `GET /api/v1/events/{eventId}/seats`
- **Response:** Seat map grid with current statuses (`available`, `held`, `booked`).

### 3. Hold Seats (Temporary Reservation)

- **Endpoint:** `POST /api/v1/seats/hold`
- **Request Body:**
  ```json
  {
    "userId": "usr_98765",
    "eventId": "evt_12345",
    "seatIds": ["seat_A1", "seat_A2"]
  }
  Response: Hold confirmation with expiration timestamp (expires_at).4. Checkout & Complete OrderEndpoint: POST /api/v1/ordersRequest Body:JSON{
  "userId": "usr_98765",
  "holdId": "hold_54321",
  "paymentDetails": {
    "token": "tok_visa_debit",
    "amount": 150.00
  }
  }
  Response: Order confirmation, ticket IDs, and receipt details.5. View User TicketsEndpoint: GET /api/v1/users/{userId}/ticketsResponse: List of valid tickets owned by the user.4. Data Model & Relationships[Users] 1 ---- * [Orders]
  [Events] 1 ---- * [Seats]
  [Events] 1 ---- * [Orders]
  [Orders] 1 ---- * [OrderItems]
  [Seats] 1 ---- 1 [OrderItems] (or linked via order)
  TablesUsers: Stores user account details (id, email, password_hash, created_at).Events: Stores concert and venue information (id, title, date, venue, total_seats).Seats: Represents individual physical seats (id, event_id, seat_number, status [ENUM: available, held, booked], held_until, version).Orders: Records completed purchases (id, user_id, event_id, total_amount, status, created_at).OrderItems: Junction table mapping orders to specific purchased seats (id, order_id, seat_id).5. Preventing Double-BookingTo guarantee that two users never purchase the exact same seat, TicketHub uses a two-phase state machine with pessimistic database transactions and optimistic locking:State Machine: Seats transition strictly from available $\rightarrow$ held $\rightarrow$ booked.Database Transactions & Locking: When a user requests to hold seats (POST /api/v1/seats/hold), the database executes a transaction using row-level locking (SELECT ... FOR UPDATE):The database locks the requested seat rows.It checks whether all requested seats have status = 'available' (or if an existing hold has expired where held_until < NOW()).If valid, it updates the status to held, sets held_until = NOW() + INTERVAL 10 MINUTE, and increments a version column.Expiration Handling: A background worker periodically releases expired holds (held $$ available where held_until < NOW()).Final Payment Validation: At checkout (POST /api/v1/orders), the system verifies that the hold is still active and owned by the user before committing the transaction and updating the status to booked.6. Architecture & Scale[Users / Clients]
       │
       ▼
  [Cloudflare CDN / WAF] (DDoS Protection & Static Asset Caching)
       │
       ▼
  [Load Balancer (NGINX)]
       │
       ├──────────────────────────────┐
       ▼                              ▼
  [Virtual Waiting Room (Redis Queue)] [Stateless API Service Nodes (Node.js/Go)]
                                      │
                                      ├───────────────────┐
                                      ▼                   ▼
                          [Redis Cache (Event/Seats)] [Primary PostgreSQL DB (Writes & Locks)]
                                                          │
                                                  [Read Replicas (Browsing)]
  Component ExplanationCDN / WAF: Absorbs malicious traffic, mitigates DDoS attacks, and caches static frontend assets.Load Balancer (NGINX): Distributes incoming HTTP traffic evenly across application server instances.Virtual Waiting Room (Redis): During major flash sales, excess traffic is diverted into a FIFO queue. Users are admitted in controlled batches (e.g., 2,000 users per minute) to protect backend services from crashing.Stateless API Services: Handle business logic, authentication, queue validation, and payment gateway integration.Caching Layer (Redis): Caches event listings and seat map statuses to reduce read pressure on the primary database during heavy browsing.Relational Database (PostgreSQL): Primary database configured with connection pooling. Read replicas handle browsing queries, while write operations and seat locking transactions hit the primary node.7. Trade-offsVirtual Waiting Room vs. Immediate Access:Trade-off: Forcing users into a waiting room introduces artificial friction and waiting time during big sales. However, it prevents total system collapse and ensures fair, orderly access rather than a chaotic server crash.Pessimistic Row-Level Locking vs. High Concurrency Throughput:Trade-off: Using strict database locks (FOR UPDATE) guarantees 100% correctness (zero double-bookings), but can introduce contention bottlenecks when thousands of users contend for adjacent seats simultaneously. We mitigate this by caching seat maps and using Redis for fast pre-checks before hitting the relational database lock.
  ```

## 4. Data Model & Relationships

[Users] 1 ---- _ [Orders]
[Events] 1 ---- _ [Seats]
[Events] 1 ---- _ [Orders]
[Orders] 1 ---- _ [OrderItems]
[Seats] 1 ---- 1 [OrderItems] (or linked via order)

### Tables

1. **`Users`**: Stores user account details (`id`, `email`, `password_hash`, `created_at`).
2. **`Events`**: Stores concert and venue information (`id`, `title`, `date`, `venue`, `total_seats`).
3. **`Seats`**: Represents individual physical seats (`id`, `event_id`, `seat_number`, `status` [ENUM: `available`, `held`, `booked`], `held_until`, `version`).
4. **`Orders`**: Records completed purchases (`id`, `user_id`, `event_id`, `total_amount`, `status`, `created_at`).
5. **`OrderItems`**: Junction table mapping orders to specific purchased seats (`id`, `order_id`, `seat_id`).

---

## 5. Preventing Double-Booking

To guarantee that two users never purchase the exact same seat, TicketHub uses a **two-phase state machine with pessimistic database transactions and optimistic locking**:

1. **State Machine:** Seats transition strictly from `available` $\rightarrow$ `held` $\rightarrow$ `booked`.
2. **Database Transactions & Locking:** When a user requests to hold seats (`POST /api/v1/seats/hold`), the database executes a transaction using row-level locking (`SELECT ... FOR UPDATE`):
   - The database locks the requested seat rows.
   - It checks whether all requested seats have `status = 'available'` (or if an existing hold has expired where `held_until < NOW()`).
   - If valid, it updates the status to `held`, sets `held_until = NOW() + INTERVAL 10 MINUTE`, and increments a `version` column.
3. **Expiration Handling:** A background worker periodically releases expired holds (`held` $\rightarrow$ `available` where `held_until < NOW()`).
4. **Final Payment Validation:** At checkout (`POST /api/v1/orders`), the system verifies that the hold is still active and owned by the user before committing the transaction and updating the status to `booked`.

---

## 6. Architecture & Scale

[Users / Clients]
│
▼
[Cloudflare CDN / WAF] (DDoS Protection & Static Asset Caching)
│
▼
[Load Balancer (NGINX)]
│
├──────────────────────────────┐
▼ ▼
[Virtual Waiting Room (Redis Queue)] [Stateless API Service Nodes (Node.js/Go)]
│
├───────────────────┐
▼ ▼
[Redis Cache (Event/Seats)] [Primary PostgreSQL DB (Writes & Locks)]
│
[Read Replicas (Browsing)]

### Component Explanation

- **CDN / WAF:** Absorbs malicious traffic, mitigates DDoS attacks, and caches static frontend assets.
- **Load Balancer (NGINX):** Distributes incoming HTTP traffic evenly across application server instances.
- **Virtual Waiting Room (Redis):** During major flash sales, excess traffic is diverted into a FIFO queue. Users are admitted in controlled batches (e.g., 2,000 users per minute) to protect backend services from crashing.
- **Stateless API Services:** Handle business logic, authentication, queue validation, and payment gateway integration.
- **Caching Layer (Redis):** Caches event listings and seat map statuses to reduce read pressure on the primary database during heavy browsing.
- **Relational Database (PostgreSQL):** Primary database configured with connection pooling. Read replicas handle browsing queries, while write operations and seat locking transactions hit the primary node.
