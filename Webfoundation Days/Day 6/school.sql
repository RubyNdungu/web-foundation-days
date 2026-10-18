
CREATE TABLE students (
    student_id INTEGER PRIMARY KEY AUTOINCREMENT,
    first_name TEXT NOT NULL,
    last_name TEXT NOT NULL,
    email TEXT NOT NULL UNIQUE
);

CREATE TABLE courses (
    course_id INTEGER PRIMARY KEY AUTOINCREMENT,
    course_name TEXT NOT NULL,
    credits INTEGER NOT NULL
);

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
INSERT INTO students (first_name, last_name, email) VALUES
('Alice', 'Smith', 'alice@example.com'),
('Bob', 'Jones', 'bob@example.com'),
('Charlie', 'Brown', 'charlie@example.com'),
('Diana', 'Prince', 'diana@example.com');

INSERT INTO courses (course_name, credits) VALUES
('Introduction to SQL', 3),
('Advanced Python', 4),
('Web Development', 3);

INSERT INTO enrolments (student_id, course_id, grade) VALUES
(1, 1, 'A'),   
(1, 2, 'B+'),  
(2, 1, 'B'),   
(2, 3, 'A-'),  
(3, 2, 'C');  

SELECT c.course_name, e.grade
FROM students s
JOIN enrolments e ON s.student_id = e.student_id
JOIN courses c ON e.course_id = c.course_id
WHERE s.first_name = 'Alice' AND s.last_name = 'Smith';

SELECT c.course_name, e.grade
FROM students s
JOIN enrolments e ON s.student_id = e.student_id
JOIN courses c ON e.course_id = c.course_id
WHERE s.first_name = 'Alice' AND s.last_name = 'Smith';

SELECT s.first_name, s.last_name, e.grade
FROM courses c
JOIN enrolments e ON c.course_id = e.course_id
JOIN students s ON e.student_id = s.student_id
WHERE c.course_name = 'Introduction to SQL';

SELECT c.course_name, COUNT(e.student_id) AS total_students
FROM courses c
LEFT JOIN enrolments e ON c.course_id = e.course_id
GROUP BY c.course_id, c.course_name;

SELECT s.first_name, s.last_name
FROM students s
LEFT JOIN enrolments e ON s.student_id = e.student_id
WHERE e.enrolment_id IS NULL;

UPDATE enrolments
SET grade = 'A'
WHERE student_id = (SELECT student_id FROM students WHERE first_name = 'Bob' AND last_name = 'Jones')
AND course_id = (SELECT course_id FROM courses WHERE course_name = 'Introduction to SQL');
