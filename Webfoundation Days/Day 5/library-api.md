Markdown

# Library API Design: Books Resource

## Endpoints

### 1. List All Books

- **Method:** `GET`
- **Path:** `/books`
- **Description:** Retrieves a complete list of all books in the library.
- **Success Status Code:** `200 OK`

### 2. Get One Book

- **Method:** `GET`
- **Path:** `/books/{id}`
- **Description:** Retrieves the details of a single book by its unique ID.
- **Success Status Code:** `200 OK`

### 3. Create a Book

- **Method:** `POST`
- **Path:** `/books`
- **Description:** Adds a new book to the library collection.
- **Request Body Example:**
  ```json
  {
    "title": "The Hobbit",
    "author": "J.R.R. Tolkien",
    "publishedYear": 1937
  }
  Success Status Code: 201 Created
  ```

4. Update a Book
   Method: PUT

Path: /books/{id}

Description: Fully updates an existing book's information by its ID.

Request Body Example:

JSON
{
"title": "The Hobbit: Illustrated Edition",
"author": "J.R.R. Tolkien",
"publishedYear": 2020
}
Success Status Code: 200 OK

5. Delete a Book
   Method: DELETE

Path: /books/{id}

Description: Removes a book from the library collection by its ID.

Success Status Code: 204 No Content

6. List Books by Author
   Method: GET

Path: /books?author={author_name}

Description: Retrieves a list of books filtered by a specific author using a query parameter.

Success Status Code: 200 OK

Error Codes
400 Bad Request
Example scenario: Happens when a client sends a POST /books request to create a new book, but forgets to include a required field in the JSON body, such as the book's title.

404 Not Found
Example scenario: Happens when a client makes a GET /books/999 request, but no book with the ID of 999 exists in the database.
