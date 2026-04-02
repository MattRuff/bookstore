# Bookstore API

A simple Rails 8 JSON REST API for managing books. Built with SQLite.

## Endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | `/books.json` | List all books |
| POST | `/books.json` | Create a book |
| GET | `/books/:id.json` | Get a book |
| PATCH | `/books/:id.json` | Update a book |
| DELETE | `/books/:id.json` | Delete a book |

### Book fields

```json
{
  "title": "string",
  "author": "string",
  "genre": "string",
  "published_year": "integer"
}
```

### Example requests

```bash
# List books
curl http://localhost:3000/books.json

# Create
curl -X POST http://localhost:3000/books.json \
  -H "Content-Type: application/json" \
  -d '{"book":{"title":"1984","author":"George Orwell","genre":"Dystopian","published_year":1949}}'

# Update
curl -X PATCH http://localhost:3000/books/1.json \
  -H "Content-Type: application/json" \
  -d '{"book":{"genre":"Classic"}}'

# Delete
curl -X DELETE http://localhost:3000/books/1.json
```

---

## Deploy on a fresh EC2 (Ubuntu 22.04+)

### 1. Launch an EC2 instance

- AMI: **Ubuntu 22.04 LTS**
- Instance type: `t3.micro` or larger
- Security group: open port **3000** (TCP) to your IP or `0.0.0.0/0`

### 2. SSH in and run the bootstrap script

```bash
ssh -i your-key.pem ubuntu@<your-ec2-ip>

# Clone the repo
git clone https://github.com/MattRuff/bookstore.git
cd bookstore

# Run the one-shot setup (installs Ruby, gems, DB, starts server)
bash bin/setup-ec2.sh
```

The script will:
1. Install system dependencies via `apt`
2. Install `rbenv` + Ruby 3.3.6
3. Run `bundle install`
4. Create & migrate the SQLite database
5. Start the Rails server on port 3000

### 3. Test it

```bash
curl http://<your-ec2-ip>:3000/books.json
```

---

## Local development

```bash
bundle install
rails db:create db:migrate
rails server
```
