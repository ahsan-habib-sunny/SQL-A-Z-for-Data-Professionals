-- DISPLAY A TABLE 'ROLL' WHICH HAS 1 TO 10 WITHOUT USING ANY IN BUILT FUCNBTION AND KEEP IT IN A VIEW

DROP VIEW STUDENTS_ROLL ;

CREATE VIEW STUDENTS_ROLL AS
WITH STUDENTS_ROLL(ROLL_NUMBER)
AS
(
SELECT 1 AS ROLL_NUMBER
UNION ALL
SELECT ROLL_NUMBER + 1 AS ROLL_NUMBER
FROM STUDENTS_ROLL
)
SELECT *
FROM STUDENTS_ROLL ;

---- 

-- Create Table
DROP TABLE IF EXISTS employee;

-- 1. Create the Table
IF OBJECT_ID('dbo.employee', 'U') IS NOT NULL
    DROP TABLE dbo.employee;
GO

CREATE TABLE employee (
    id INT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    designation VARCHAR(100) NOT NULL,
    manager_id INT,
    CONSTRAINT fk_manager 
        FOREIGN KEY (manager_id) 
        REFERENCES employee(id) 
        ON DELETE NO ACTION
);
GO

-- 2. Insert the 20 Hierarchy Rows
INSERT INTO employee (id, name, designation, manager_id) VALUES
(1,  'Sarah Connor',     'CEO',                    NULL), -- Level 1 (Root)
(2,  'John Smith',       'VP of Engineering',     1),    -- Level 2
(3,  'Emily Davis',      'VP of HR',              1),    -- Level 2
(4,  'Michael Scott',    'VP of Sales',           1),    -- Level 2
(5,  'Alex Mercer',      'Engineering Manager',   2),    -- Level 3
(6,  'Jessica Roy',      'QA Lead',               2),    -- Level 3
(7,  'David Miller',     'Senior Architect',      2),    -- Level 3
(8,  'Rachel Adams',     'HR Lead',               3),    -- Level 3
(9,  'James Wilson',     'Recruiting Manager',    3),    -- Level 3
(10, 'Dwight Schrute',   'Sales Manager',         4),    -- Level 3
(11, 'Jim Halpert',      'Senior Account Exec',   4),    -- Level 3
(12, 'Carlos Ruiz',      'Senior Backend Dev',    5),    -- Level 4
(13, 'Priya Patel',      'Senior Frontend Dev',   5),    -- Level 4
(14, 'Kevin Malone',     'QA Engineer',           6),    -- Level 4
(15, 'Angela Martin',    'HR Specialist',         8),    -- Level 4
(16, 'Oscar Martinez',   'Recruiter',             9),    -- Level 4
(17, 'Pam Beesly',       'Sales Rep',             10),   -- Level 4
(18, 'Ryan Howard',      'Junior Dev',            12),   -- Level 5
(19, 'Kelly Kapoor',     'UI Trainee',            13),   -- Level 5
(20, 'Andy Bernard',     'Junior Sales Rep',      17);   -- Level 5
GO


-- Recursive SQl 

SELECT * FROM employee;


-- FIND THE HIERARCHY OF EMPLOEYEES UDER A GIVEN MANAGER 'Alex Mercer'

WITH EMPLOYEES_UNDER_MANAGER
AS
(
SELECT * FROM employee WHERE NAME = 'Alex Mercer'
UNION ALL
SELECT B.* FROM EMPLOYEES_UNDER_MANAGER A
JOIN employee B ON A.id = B.manager_id)

SELECT *
FROM EMPLOYEES_UNDER_MANAGER;


---- FIND THE HIERARCHY OF MANAGERS FOR A GIVEN EMPLOYEE 'Oscar Martinez'

WITH TOP_LEVEL_MANAGERS
AS
(
SELECT * FROM employee WHERE name = 'Oscar Martinez'
UNION ALL
SELECT B.* FROM TOP_LEVEL_MANAGERS A
JOIN employee B ON A.manager_id = B.id
)
SELECT *
FROM TOP_LEVEL_MANAGERS
ORDER BY manager_id;