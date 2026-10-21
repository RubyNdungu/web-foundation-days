Day 7 Assignment
Scaling a Photo Sharing App
Scaling Plan for “Snap share.”
10 million registered users; 10% active each day; each active user uploads 1 photo per day and views 50 feed pages per day; an average photo is 2 MB, and each photo also gets a 50 KB thumbnail.

1. Write down the assumptions and work out the daily active users
   The description
   • There are 10,000,000 registered users.
   • 10% of them use the app on a given day, resulting in 1,000,000 daily active users (DAU).
   • Each active user uploads 1 photo per day.
   • Each active user views 50 feed pages per day.
   • Each upload requires storing 2.05 MB total (2 MB for the average photo + 50 KB for the thumbnail).
2. Calculate uploads per second, feed views per second (average and peak, using 5× for peak) and photo storage per year.
   The Calculation: Seconds in a day ≈ 100,000 (rounded for easy maths)
   Uploads (Writes): 1,000,000 users × 1 photo = 1,000,000 uploads per day 1,000,000 ÷ 100,000 ≈ 10 uploads per second
   Feed Views (Reads): 1,000,000 users × 50 views = 50,000,000 views per day 50,000,000 ÷ 100,000 ≈ 500 views per second
   Peak Traffic (5× the average): Uploads: 10 × 5 = 50 uploads per second Views: 500 × 5 = 2,500 views per second
   Storage per year: Total size per upload = 2.05 MB 1,000,000 uploads/day × 2.05 MB = 2,050,000 MB per day 2,050,000 MB = 2,050 GB = 2.05 TB per day 2.05 TB × 365 days ≈ 748.25 TB (often rounded to ~750 TB per year)
3. Decide whether the system is read-heavy or write-heavy, and explain what that means for the design.
   The system is significantly read-heavy, with a read-to-write ratio of 50 to 1 (50,000,000 feed views per day compared to 1,000,000 photo uploads). This means the infrastructure will spend the vast majority of its computing power and network bandwidth fetching and serving existing content rather than processing and saving new data.
   What this means for the design:
   • Caching is mandatory: Because users will frequently request the same feed data and popular photos, placing a fast in-memory cache (like Redis or Memcached) in front of the database will easily absorb the bulk of the 2,500 peak reads per second, preventing the database from being overwhelmed.
   • Database read replicas: The database architecture should be optimized for reading. A standard approach is to use a single primary database to handle the 50 peak writes per second (which is a very light load), paired with multiple "read replica" databases that strictly handle read queries to distribute the 500+ read operations per second.
   • Content Delivery Networks (CDNs): Serving massive volumes of 2 MB photos directly from your application servers would quickly exhaust their bandwidth. A CDN will cache these static media files on edge servers globally, serving them to users locally and keeping that heavy traffic completely off your main application servers.
   • Separation of storage: You cannot store ~750 TB of media files inside a standard relational database. The heavy media files (photos and thumbnails) must be stored in highly scalable object storage (like AWS S3 or Google Cloud Storage), while the main database only stores the lightweight metadata (e.g., the URL to the photo, the user ID of the uploader, and timestamps).
4. Explain why photos should not be stored inside the database, and where they should go instead.
   Storing 750 TB of media files directly inside a traditional database (as BLOBs, or Binary Large Objects) is an architectural anti-pattern that will quickly degrade performance and skyrocket costs.
   Why photos should not go in the database:
   • Cost of Storage: Database storage requires highly optimized, premium SSDs to handle rapid read/write queries. Paying for database-grade storage for hundreds of terabytes of static photos is incredibly expensive compared to standard file storage.
   • Memory Thrashing: Databases rely on keeping frequently accessed data in RAM for speed. Large image files will rapidly consume this memory pool, pushing out the lightweight text and metadata the database actually needs to process queries quickly.
   • Nightmarish Backups: Backing up or restoring a database containing hundreds of terabytes of binary data takes an impractical amount of time. In a disaster recovery scenario, your system could be offline for days just restoring photos.
   • Bandwidth Bottlenecks: Routing massive 2 MB photo files through your database and application servers consumes their network bandwidth, leaving less capacity for processing actual user actions and API requests.
   Where they should go instead:
   Photos and thumbnails should be stored in Distributed Object Storage (such as Amazon S3, Google Cloud Storage, or Azure Blob Storage). These services are infinitely scalable, inexpensive, and purpose-built for hosting static files.
   In this architecture, the responsibilities are split:
   i. The Object Storage holds the actual physical image files.
   ii. The Database holds only the metadata—a lightweight text record containing the image's URL, the user ID of the uploader, timestamps, and the file size.
   When a user views a feed, the database instantly returns the lightweight text URLs, and the user's browser or app downloads the heavy image files directly from the object storage (ideally routed through a CDN for faster global loading).
5. Draw the architecture in a text diagram

Plaintext
[ Users / Client App ]
|
v
[ CDN ] ------------------------------------+
| |
v |
[ Load Balancer ] | (Serves media)
| v
[ App Servers ] ---------------------> [ Object Storage ]
/ | \ ^
/ | \ | (Saves images)
v v v |
[Cache] [DB] [Message Queue] ---> [ Worker ] ----+

6. Explain each component in one sentence.
   Architecture Components
   • Client App: The mobile application or web browser where users interact with the platform, view feeds, and upload photos.
   • CDN (Content Delivery Network): A global network of edge servers that caches and delivers heavy static media (photos and thumbnails) directly to users from geographical locations close to them.
   • Load Balancer: A routing node that distributes incoming API requests evenly across multiple application servers to prevent any single machine from being overloaded.
   • App Servers: The core backend machines that handle business logic, process incoming API requests, coordinate data flow, and serve lightweight JSON responses.
   • Object Storage: A highly scalable, flat file storage system (like Amazon S3) designed to permanently hold the massive volume of heavy binary files (the 2 MB photos and 50 KB thumbnails).
   • Database: The persistent relational or NoSQL data store that holds only the lightweight text metadata, such as user profiles, feed timelines, and the URLs pointing to the images in object storage.
   • Cache: A blazing-fast, in-memory data store (like Redis) placed in front of the database to hold the most frequently requested feed data, absorbing the heavy read traffic.
   • Message Queue: A temporary buffer (like RabbitMQ or Kafka) that holds background task instructions, decoupling heavy processing jobs from the main user-facing application servers.
   • Worker: An asynchronous backend server that continuously pulls tasks from the message queue and executes heavy background jobs, such as image resizing, without making the user wait.
7. Describe the upload flow step by step, including the thumbnail job
   The Upload & Thumbnail Flow
   i. Upload Initiation: The user selects a 2 MB photo in the Client App and sends an upload request through the Load Balancer to an App Server.
   ii. File Storage: The App Server receives the file, authenticates the request, and immediately uploads the original 2 MB photo directly to the Object Storage.
   iii. Metadata Save: Once Object Storage confirms receipt and returns a file URL, the App Server writes a new record to the Database containing the photo's metadata (uploader ID, timestamp, and original photo URL).
   iv. Queueing the Job: To avoid making the user wait for image processing, the App Server drops a "generate thumbnail" task into the Message Queue and immediately sends a "Success" response back to the user's Client App.
   v. Background Processing: A Worker node picks up the task from the Message Queue, downloads the original photo from Object Storage into its local memory, and compresses it into a 50 KB thumbnail.
   vi. Finalization: The Worker uploads the newly generated 50 KB thumbnail to the Object Storage and updates the existing photo record in the Database to include the new thumbnail URL, making it available for users viewing their feeds.

8. Describe at least two trade-offs.

i) App Server Uploads vs. Direct-to-Storage Uploads (Bandwidth vs. Complexity)
• The Design Choice: The current flow routes the 2 MB photo upload through the App Server before pushing it to Object Storage.
• The Trade-off: This approach is much simpler to build and makes it easy to validate the file type and size. However, passing every 2 MB file through the App Servers consumes their network bandwidth and CPU. The alternative is generating a temporary "presigned URL" to allow the user's phone to upload the photo directly to Object Storage. This saves server bandwidth, but makes the client application logic and security authentication significantly more complex.
ii) Caching Performance vs. Data Freshness (The CDN and Redis)
• The Design Choice: Using a CDN for images and an in-memory cache for feeds to handle the heavy read load.
• The Trade-off: We trade strict data accuracy for high performance. Cache invalidation is notoriously difficult. If a user deletes a photo or changes their profile picture, the database updates instantly. However, the old photo might still be served from the CDN edge servers or the Redis feed cache until the "Time To Live" (TTL) expires. The system must accept that some users will see stale data for a short period.
