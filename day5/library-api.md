# Library Books REST API

This API provides endpoints for managing books in a library system.

## 1. List all books

- **Method:** `GET`
- **Path:** `/api/books`
- **Description:** Returns a list of all books.
- **Success status:** `200 OK`

## 2. Get one book

- **Method:** `GET`
- **Path:** `/api/books/:id`
- **Description:** Returns a single book using its ID.
- **Success status:** `200 OK`

## 3. Create a book

- **Method:** `POST`
- **Path:** `/api/books`
- **Description:** Creates a new book.
- **Example request body:**

```json
{
  "title": "Things Fall Apart",
  "author": "Chinua Achebe",
  "year": 1958
}
```
