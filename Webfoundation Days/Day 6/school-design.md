# Day 6 Task: School Database Design

## 1. Database Design & Architecture

### Table Explanations

- **Students:** Stores the core identity information for individuals attending the school, including their name and a unique email address to ensure no duplicate accounts are created.
- **Courses:** Stores the details of the classes being offered by the school, including the course name and the number of credits it is worth.
- **Enrolments:** Acts as the bridge connecting a student to a course, while also storing data specific to that pairing (the student's grade).

### Relationships & The Join Table

The relationship between Students and Courses is **many-to-many**: a single student can take many courses, and a single course can have many students.

Relational databases cannot directly link many-to-many entities. Therefore, a **join table** (`enrolments`) is needed to break this down into two **one-to-many** relationships:

1.  One student has _many_ enrolments.
2.  One course has _many_ enrolments.

### Indexing

If I were to add an index, I would add one to the student's last name (`CREATE INDEX idx_last_name ON students(last_name);`). In a real school system, administrators and teachers frequently search for students by their last name. As the database grows to thousands of students, this index would significantly speed up those search queries without requiring the database to scan every single row.

### SQL vs. NoSQL

For a school enrolment system, **SQL** is definitely the better choice. School data is highly structured and relies on strict relationships and data integrity (ACID properties). We need strict rules—like foreign keys—to ensure that a grade is never accidentally assigned to a deleted student or a non-existent course. SQL's relational model enforces these constraints naturally and prevents data duplication. NoSQL is better suited for unstructured data or rapidly changing schemas, whereas a school's core entities (students, courses, grades) remain very consistent over time.

---

## 2. Table Setup (Drop & Create)

```sql
-- Safely drop existing tables to allow re-running the script
DROP TABLE IF EXISTS enrolments;
DROP TABLE IF EXISTS courses;
DROP TABLE IF EXISTS students;

-- Create the Students table
CREATE TABLE students (
    student_id INTEGER PRIMARY KEY AUTOINCREMENT,
    first_name TEXT NOT NULL,
    last_name TEXT NOT NULL,
    email TEXT NOT NULL UNIQUE
);

-- Create the Courses table
CREATE TABLE courses (
    course_id INTEGER PRIMARY KEY AUTOINCREMENT,
    course_name TEXT NOT NULL,
    credits INTEGER NOT NULL
);

-- Create the Enrolments table
CREATE TABLE enrolments (
    enrolment_id INTEGER PRIMARY KEY AUTOINCREMENT,
    student_id INTEGER NOT NULL,
    course_id INTEGER NOT NULL,
    grade TEXT,
    FOREIGN KEY (student_id) REFERENCES students(student_id),
    FOREIGN KEY (course_id) REFERENCES courses(course_id),
    -- Prevents the same student enrolling on the same course twice
    UNIQUE (student_id, course_id)
);
3. Sample Data Insertion
SQL
-- Insert 4 students (including one who will have no enrolments)
INSERT INTO students (first_name, last_name, email) VALUES
('Alice', 'Smith', 'alice@example.com'),
('Bob', 'Jones', 'bob@example.com'),
('Charlie', 'Brown', 'charlie@example.com'),
('Diana', 'Prince', 'diana@example.com');

-- Insert 3 courses
INSERT INTO courses (course_name, credits) VALUES
('Introduction to SQL', 3),
('Advanced Python', 4),
('Web Development', 3);

-- Insert 5 enrolments
INSERT INTO enrolments (student_id, course_id, grade) VALUES
(1, 1, 'A'),   -- Alice in SQL
(1, 2, 'B+'),  -- Alice in Python
(2, 1, 'B'),   -- Bob in SQL
(2, 3, 'A-'),  -- Bob in Web Dev
(3, 2, 'C');   -- Charlie in Python
4. Required Queries
Query 1: All courses for one student (by name)

SQL
SELECT c.course_name, e.grade
FROM students s
INNER JOIN enrolments e ON s.student_id = e.student_id
INNER JOIN courses c ON e.course_id = c.course_id
WHERE s.first_name = 'Alice' AND s.last_name = 'Smith';
Query 2: All students on one course

SQL
SELECT s.first_name, s.last_name, e.grade
FROM courses c
INNER JOIN enrolments e ON c.course_id = e.course_id
INNER JOIN students s ON e.student_id = s.student_id
WHERE c.course_name = 'Introduction to SQL';
Query 3: The number of students per course

SQL
SELECT c.course_name, COUNT(e.student_id) AS total_students
FROM courses c
LEFT JOIN enrolments e ON c.course_id = e.course_id
GROUP BY c.course_id, c.course_name;
Query 4: Students who have no enrolments

SQL
SELECT s.first_name, s.last_name
FROM students s
LEFT JOIN enrolments e ON s.student_id = e.student_id
WHERE e.enrolment_id IS NULL;
Query 5: Update one enrolment's grade

SQL
-- Updating Bob Jones's grade in Introduction to SQL from 'B' to 'A'
UPDATE enrolments
SET grade = 'A'
WHERE student_id = (SELECT student_id FROM students WHERE first_name = 'Bob' AND last_name = 'Jones')
  AND course_id = (SELECT course_id FROM courses WHERE course_name = 'Introduction to SQL');

```
