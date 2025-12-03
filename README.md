# Apollo - Court Caseworker Task Management

A Rails 8 application for managing court caseworker tasks with database persistence.

## Getting Started

To launch the application:

```bash
cd apollo
bin/rails server
```

The application will be available at `http://localhost:3000`

## Features

- Create, view, and edit tasks
- Track task status (Pending, In Progress, Completed, Failed)
- Set due dates/times for tasks
- Add optional task descriptions
- View overdue task indicators

## Setup

If this is your first time running the application:

```bash
bin/rails db:setup
bin/rails db:seed
bin/rails server
```

This will create the database, run migrations, seed sample court caseworker tasks, and start the server.
