# PROCEDURE SQL PRACTICE

USE company_db;

# PRODUCT TABLE

CREATE TABLE PRODUCT (
product_id INT PRIMARY KEY AUTO_INCREMENT,
name VARCHAR(100) NOT NULL,
price DECIMAL(10, 2) NOT NULL CHECK (price >= 0),
quantity_remaining INT NOT NULL DEFAULT 0 CHECK (quantity_remaining>=0),
quantity_sold INT NOT NULL DEFAULT 0 CHECK (quantity_sold>=0)) ;

INSERT INTO PRODUCT (name, price, quantity_remaining, quantity_sold)
VALUES
('AIRPODS PRO 1', 100, 56, 23),
('AIRPODS PRO 2', 150, 34, 45),
('AIRPODS PRO 3', 200, 65, 23),
('AIRPODS PRO 4', 180, 23, 98) ;

# SALES TABLE

CREATE TABLE SALES (
order_date DATE,
product_id INT,
quantity_ordered INT NOT NULL,
sale_price DECIMAL(10, 2) NOT NULL CHECK (sale_price >= 0));

INSERT INTO SALES (order_date, product_id, quantity_ordered, sale_price) VALUES
-- Product 1 Sales
('2026-01-10', 1, 5, 29.99),
('2026-01-15', 1, 2, 29.99),
('2026-02-01', 1, 10, 27.50),

-- Product 2 Sales
('2026-01-12', 2, 1, 89.50),
('2026-01-20', 2, 3, 89.50),
('2026-02-05', 2, 4, 85.00),

-- Product 3 Sales
('2026-01-18', 3, 2, 249.00),
('2026-02-10', 3, 1, 249.00),

-- Product 4 Sales
('2026-01-22', 4, 12, 120.00),
('2026-02-03', 4, 8, 120.00),
('2026-02-12', 4, 15, 115.00);

# LET'S CHECK THE TABLE

SELECT * FROM PRODUCT ;
SELECT * FROM SALES;

# UPDATE THE TABLE 'PRODUCT' TABLE FOR 'AIRPODS PRO 1' USING PROCEDURE WITHOUT MENTIONING PARAMETERS 


DROP PROCEDURE IF EXISTS PR_BUY_PRODUCT;

DELIMITER $$

CREATE PROCEDURE PR_BUY_PRODUCT(
    -- Parameter list goes here
)
BEGIN
    DECLARE v_product_id INT ;
    DECLARE v_price DECIMAL(10, 2) ;
    
    SELECT product_id, price
    INTO v_product_id, v_price
    FROM PRODUCT
    WHERE name = 'AIRPODS PRO 1' ;
    
    INSERT INTO SALES 
    VALUES
    (CURRENT_DATE, v_product_id, 1, v_price) ;
    
    UPDATE PRODUCT
    SET quantity_remaining = quantity_remaining - 1 ,
		quantity_sold = quantity_sold + 1
	WHERE product_id = v_product_id ;
    
    SELECT 'PRODUCT SOLD SUCCESSFULLY!' AS MESSAGE ;
END $$ 

CALL PR_BUY_PRODUCT;

SELECT * FROM PRODUCT;


# WITH PARAMETERS
# FOR EVERY GIVEN PRODUCT CHECK IF THE PRODUCT IS AVAILABLE IN THE REQUIRED QUANTITY 
# AND THEN, UPDATE THE TABLE 'PRODUCT' TABLE FOR GIVEN PRODCUT USING PROCEDURE MENTIONING PARAMETERS 

DROP PROCEDURE IF EXISTS UPDATED_PR_BUY_PRODUCT;

DELIMITER $$

CREATE PROCEDURE UPDATED_PR_BUY_PRODUCT (PM_PRODUCT_ID INT, PM_PRODUCT_QUANTITY INT)
BEGIN
	DECLARE v_product_id INT ;
    DECLARE v_price DECIMAL(10, 2) ;
    DECLARE v_count INT;
    
    SELECT COUNT(1) INTO v_count 
    FROM PRODUCT 
    WHERE product_id = PM_PRODUCT_ID AND quantity_remaining >= PM_PRODUCT_QUANTITY ;
    
    IF v_count > 0 THEN
		SELECT product_id, price
        INTO v_product_id, v_price
        FROM PRODUCT
        WHERE product_id = PM_PRODUCT_ID ;
        
        INSERT INTO SALES
        VALUES(CURRENT_DATE, v_product_id, quantity_ordered + PM_PRODUCT_QUANTITY, PM_PRODUCT_QUANTITY * v_price) ;
        
        UPDATE PRODUCT
        SET quantity_remaining = quantity_remaining - PM_PRODUCT_QUANTITY, 
			quantity_sold = quantity_sold + PM_PRODUCT_QUANTITY
        WHERE product_id = v_product_id ;
        
        SELECT 'PRODUCT SOLD SUCCESSFULLY!' AS MESSAGE ;
	ELSE 
		SELECT CONCAT('WE HAVE ', quantity_remaining, ' IN STOCK') AS MESSAGE 
		FROM PRODUCT 
		WHERE product_id = PM_PRODUCT_ID;
	END IF;
END $$


# ALTERNATIVELY

DROP PROCEDURE IF EXISTS UPDATED_PR_BUY_PRODUCT_1;

DELIMITER $$

CREATE PROCEDURE UPDATED_PR_BUY_PRODUCT_1 (PM_PRODUCT_ID INT, PM_PRODUCT_QUANTITY INT)
BEGIN
	DECLARE v_product_id INT ;
    DECLARE v_price DECIMAL(10, 2) ;
    
	SELECT product_id, price
	INTO v_product_id, v_price
	FROM PRODUCT
	WHERE product_id = PM_PRODUCT_ID AND quantity_remaining >= PM_PRODUCT_QUANTITY;
	
    IF v_product_id IS NOT NULL THEN
		INSERT INTO SALES
		VALUES(CURRENT_DATE, v_product_id, quantity_ordered + PM_PRODUCT_QUANTITY, PM_PRODUCT_QUANTITY * v_price) ;
		
		UPDATE PRODUCT
		SET quantity_remaining = quantity_remaining - PM_PRODUCT_QUANTITY, 
			quantity_sold = quantity_sold + PM_PRODUCT_QUANTITY
		WHERE product_id = v_product_id ;
		
		SELECT 'PRODUCT SOLD SUCCESSFULLY!' AS MESSAGE ;
	ELSE 
		SELECT CONCAT('WE HAVE ', quantity_remaining, ' IN STOCK') AS MESSAGE 
		FROM PRODUCT 
		WHERE product_id = PM_PRODUCT_ID;
	END IF;
END $$

SELECT * FROM PRODUCT;
SELECT * FROM SALES;

CALL UPDATED_PR_BUY_PRODUCT_1(1,4) ;