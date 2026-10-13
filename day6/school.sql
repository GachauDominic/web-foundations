-- Day 6: School Database
-- Enable foreign key enforcement in SQLite
PRAGMA foreign_keys = ON;

-- Remove existing tables so the script can be rerun safely
DROP TABLE IF EXISTS enrolments;
DROP TABLE IF EXISTS courses;
DROP TABLE IF EXISTS students;

-- 1. Create students table
CREATE TABLE students (
    student_id INTEGER PRIMARY KEY,
    student_name TEXT NOT NULL,
    email TEXT NOT NULL UNIQUE
);

-- 2. Create courses table
CREATE TABLE courses (
    course_id INTEGER PRIMARY KEY,
    course_name TEXT NOT NULL,
    course_description TEXT
);

-- 3. Create enrolments table
-- This join table connects students and courses.
CREATE TABLE enrolments (
    enrolment_id INTEGER PRIMARY KEY,
    student_id INTEGER NOT NULL,
    course_id INTEGER NOT NULL,
    grade TEXT,
    FOREIGN KEY (student_id)
        REFERENCES students(student_id),
    FOREIGN KEY (course_id)
        REFERENCES courses(course_id),
    UNIQUE (student_id, course_id)
);

-- 4. Insert sample students
INSERT INTO students (student_id, student_name, email) VALUES
    (1, 'Alice Kamau', 'alice@example.com'),
    (2, 'Brian Otieno', 'brian@example.com'),
    (3, 'Carol Wanjiku', 'carol@example.com'),
    (4, 'David Mwangi', 'david@example.com');

-- 5. Insert sample courses
INSERT INTO courses (course_id, course_name, course_description) VALUES
    (1, 'Database Systems', 'Introduction to relational databases'),
    (2, 'Web Development', 'HTML, CSS and JavaScript fundamentals'),
    (3, 'Networking', 'Computer networks and network administration');

-- 6. Insert sample enrolments
INSERT INTO enrolments (enrolment_id, student_id, course_id, grade) VALUES
    (1, 1, 1, 'A'),
    (2, 1, 2, 'B'),
    (3, 2, 1, 'B'),
    (4, 2, 3, 'A'),
    (5, 3, 2, 'A'),
    (6, 3, 3, 'B');

-- QUERY 1: All courses taken by one student, identified by name
SELECT
    s.student_name,
    c.course_name,
    e.grade
FROM students AS s
JOIN enrolments AS e ON s.student_id = e.student_id
JOIN courses AS c ON e.course_id = c.course_id
WHERE s.student_name = 'Alice Kamau';

-- QUERY 2: All students enrolled on one course
SELECT
    c.course_name,
    s.student_name,
    e.grade
FROM courses AS c
JOIN enrolments AS e ON c.course_id = e.course_id
JOIN students AS s ON e.student_id = s.student_id
WHERE c.course_name = 'Database Systems';

-- QUERY 3: Number of students per course, including courses with zero enrolments
SELECT
    c.course_name,
    COUNT(e.student_id) AS student_count
FROM courses AS c
LEFT JOIN enrolments AS e ON c.course_id = e.course_id
GROUP BY c.course_id, c.course_name
ORDER BY c.course_name;

-- QUERY 4: Students who have no enrolments
SELECT
    s.student_id,
    s.student_name,
    s.email
FROM students AS s
LEFT JOIN enrolments AS e ON s.student_id = e.student_id
WHERE e.student_id IS NULL;

-- QUERY 5: Update one enrolment's grade
UPDATE enrolments
SET grade = 'A'
WHERE enrolment_id = 3;

-- Optional verification: view the updated enrolment
SELECT
    s.student_name,
    c.course_name,
    e.grade
FROM enrolments AS e
JOIN students AS s ON e.student_id = s.student_id
JOIN courses AS c ON e.course_id = c.course_id
WHERE e.enrolment_id = 3;

-- Index to speed up lookups by course
CREATE INDEX idx_enrolments_course_id
ON enrolments(course_id);