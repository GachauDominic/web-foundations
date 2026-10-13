# School Database Design

## Tables

- **students:** Stores each student's unique ID, name and email address. The email is required and must be unique so that two students cannot share the same email.
- **courses:** Stores each course's unique ID, name and optional description.
- **enrolments:** Records which student is enrolled on which course, together with the student's grade for that course. It contains foreign keys referencing `students` and `courses`.

## Relationships

### One-to-many

The relationship between `students` and `enrolments` is one-to-many: one student can have multiple enrolment records, but each enrolment belongs to one student.

The relationship between `courses` and `enrolments` is also one-to-many: one course can have multiple enrolment records, but each enrolment refers to one course.

### Many-to-many

The relationship between `students` and `courses` is many-to-many. A student can enrol in multiple courses, and each course can have multiple students.

The `enrolments` table is needed as a join table to represent this relationship in a relational database. It connects students to courses through foreign keys and stores information specific to each enrolment, such as the grade. The `UNIQUE (student_id, course_id)` constraint prevents duplicate enrolments for the same student-course combination.

## Index

I would add an index on `enrolments(course_id)`. This can improve queries that retrieve students enrolled on a particular course and queries that count enrolments per course. The database also creates indexes to enforce primary key and unique constraints.

## SQL or NoSQL?

I would choose a relational SQL database such as SQLite for this school system. The data has clear relationships between students, courses and enrolments, and the system needs reliable foreign key constraints, unique values and structured queries involving joins and grouping. SQL is a good fit for maintaining data integrity and answering questions such as how many students take each course. A NoSQL database could work, but it would be less natural for this highly relational structure and would require additional care to maintain relationships and prevent duplicate enrolments.
