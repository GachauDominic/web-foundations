# Library Books REST API

The Library Books API is a RESTful API for creating, reading, updating, deleting, and filtering books in a library system.

## Endpoints

### 1. List all books

- **Method:** `GET`
- **Path:** `/api/books`
- **Description:** Returns a list of all books in the library.
- **Success status:** `200 OK`

**Example response:**

```json
[
  {
    "id": 1,
    "title": "Things Fall Apart",
    "author": "Chinua Achebe",
    "year": 1958
  },
  {
    "id": 2,
    "title": "1984",
    "author": "George Orwell",
    "year": 1949
  }
]
```

---

### 2. Get one book

- **Method:** `GET`
- **Path:** `/api/books/:id`
- **Description:** Returns a single book using its unique ID.
- **Success status:** `200 OK`

**Example request:**

```http
GET /api/books/1
```

**Example response:**

```json
{
  "id": 1,
  "title": "Things Fall Apart",
  "author": "Chinua Achebe",
  "year": 1958
}
```

If the book does not exist, the API returns `404 Not Found`.

---

### 3. Create a book

- **Method:** `POST`
- **Path:** `/api/books`
- **Description:** Creates a new book.
- **Success status:** `201 Created`

**Example request body:**

```json
{
  "title": "Things Fall Apart",
  "author": "Chinua Achebe",
  "year": 1958
}
```

**Example response:**

```json
{
  "id": 1,
  "title": "Things Fall Apart",
  "author": "Chinua Achebe",
  "year": 1958
}
```

A successful `POST` uses `201 Created` because a new resource has been created.

---

### 4. Update a book

- **Method:** `PUT`
- **Path:** `/api/books/:id`
- **Description:** Replaces or updates an existing book using its unique ID.
- **Success status:** `200 OK`

**Example request:**

```http
PUT /api/books/1
```

**Example request body:**

```json
{
  "title": "Things Fall Apart",
  "author": "Chinua Achebe",
  "year": 1958
}
```

**Example response:**

```json
{
  "id": 1,
  "title": "Things Fall Apart",
  "author": "Chinua Achebe",
  "year": 1958
}
```

If the specified book does not exist, the API returns `404 Not Found`.

> `PUT` is used here for a complete update of the book resource. A `PATCH` endpoint could alternatively be used if the API were designed for partial updates.

---

### 5. Delete a book

- **Method:** `DELETE`
- **Path:** `/api/books/:id`
- **Description:** Deletes a book using its unique ID.
- **Success status:** `204 No Content`

**Example request:**

```http
DELETE /api/books/1
```

A successful deletion returns:

```http
HTTP/1.1 204 No Content
```

A `204` response normally has no response body because the resource has been successfully deleted.

If the specified book does not exist, the API returns `404 Not Found`.

---

### 6. List books by author

- **Method:** `GET`
- **Path:** `/api/books?author={author}`
- **Description:** Returns books whose author matches the `author` query parameter.
- **Success status:** `200 OK`

**Example request:**

```http
GET /api/books?author=Chinua%20Achebe
```

**Example response:**

```json
[
  {
    "id": 1,
    "title": "Things Fall Apart",
    "author": "Chinua Achebe",
    "year": 1958
  }
]
```

The `author` value is a **query parameter**, not a path parameter. This makes it possible to filter the collection without creating a separate endpoint such as `/api/books/author/...`.

If no books match the author, the API can return:

```http
HTTP/1.1 200 OK
```

with an empty array:

```json
[]
```

---

# Error Responses

## 400 Bad Request

A `400 Bad Request` response means the server cannot process the request because the client sent invalid or incomplete data.

### Example

A client attempts to create a book but omits the required `title`:

```http
POST /api/books
Content-Type: application/json
```

```json
{
  "author": "Chinua Achebe",
  "year": 1958
}
```

The server could respond:

```http
HTTP/1.1 400 Bad Request
```

```json
{
  "error": "Title is required."
}
```

Another example would be sending an invalid value for the `year` field.

---

## 404 Not Found

A `404 Not Found` response means the requested resource cannot be found.

### Example

A client requests a book that does not exist:

```http
GET /api/books/999
```

The server could respond:

```http
HTTP/1.1 404 Not Found
```

```json
{
  "error": "Book not found."
}
```

The same status can be returned when attempting to update or delete a book whose ID does not exist.

---

# Common HTTP Responses Used by This API

| Status            | Meaning                                         | Example                                  |
| ----------------- | ----------------------------------------------- | ---------------------------------------- |
| `200 OK`          | Request succeeded and the server returns data   | `GET /api/books`                         |
| `201 Created`     | A new resource was successfully created         | `POST /api/books`                        |
| `204 No Content`  | Request succeeded but there is no response body | `DELETE /api/books/1`                    |
| `400 Bad Request` | Client sent invalid or incomplete data          | Creating a book without a required title |
| `404 Not Found`   | Requested resource does not exist               | `GET /api/books/999`                     |

## Example API Flow

A typical client interaction might look like this:

```text
GET /api/books
        ↓
200 OK
        ↓
Client receives list of books

POST /api/books
        ↓
201 Created
        ↓
Client receives the newly created book

PUT /api/books/1
        ↓
200 OK
        ↓
Client receives the updated book

DELETE /api/books/1
        ↓
204 No Content
        ↓
Client knows the deletion succeeded

GET /api/books/999
        ↓
404 Not Found
        ↓
Client displays "Book not found"

POST /api/books
        ↓
400 Bad Request
        ↓
Client displays validation error
```
