-- 如果已存在则删除，保证可重复执行
DROP TABLE IF EXISTS DrinkRecord;
DROP TABLE IF EXISTS UserPreference;
DROP TABLE IF EXISTS User;
DROP TABLE IF EXISTS Coffee;
DROP VIEW IF EXISTS v_coffee_ranking;

-- 1. 用户表
CREATE TABLE User (
    user_id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    password VARCHAR(100) NOT NULL,
    created_at DATETIME DEFAULT NOW()
);

-- 2. 咖啡表
CREATE TABLE Coffee (
    coffee_id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    shop VARCHAR(100) NOT NULL,
    type VARCHAR(50),
    popularity INT DEFAULT 0
);

-- 3. 用户偏好表
CREATE TABLE UserPreference (
    pref_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    coffee_type VARCHAR(50) NOT NULL,
    FOREIGN KEY (user_id) REFERENCES User(user_id)
);

-- 4. 饮用记录表（含杯型、温度、咖啡因、价格）
CREATE TABLE DrinkRecord (
    record_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    coffee_id INT NOT NULL,
    drink_date DATE NOT NULL,
    quantity INT DEFAULT 1,
    cup_size VARCHAR(20) DEFAULT 'Large',
    temperature VARCHAR(20) DEFAULT 'Normal',
    caffeine INT DEFAULT NULL,
    price DECIMAL(6,2) DEFAULT NULL,
    taste_score INT CHECK (taste_score BETWEEN 1 AND 10),
    FOREIGN KEY (user_id) REFERENCES User(user_id),
    FOREIGN KEY (coffee_id) REFERENCES Coffee(coffee_id)
);

-- ===================== 触发器 =====================
DROP TRIGGER IF EXISTS trg_update_popularity;
DROP TRIGGER IF EXISTS trg_check_score;

DELIMITER //

CREATE TRIGGER trg_check_score
BEFORE INSERT ON DrinkRecord
FOR EACH ROW
BEGIN
    IF NEW.taste_score < 1 OR NEW.taste_score > 10 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Score must be between 1 and 10';
    END IF;
END;//

CREATE TRIGGER trg_update_popularity
AFTER INSERT ON DrinkRecord
FOR EACH ROW
BEGIN
    UPDATE Coffee
    SET popularity = popularity + NEW.taste_score
    WHERE coffee_id = NEW.coffee_id;
END;//

DELIMITER ;

-- ===================== 存储过程 =====================
DROP PROCEDURE IF EXISTS sp_add_drink_record;

DELIMITER //

CREATE PROCEDURE sp_add_drink_record(
    IN p_user_id INT,
    IN p_coffee_id INT,
    IN p_date DATE,
    IN p_quantity INT,
    IN p_cup_size VARCHAR(20),
    IN p_temperature VARCHAR(20),
    IN p_caffeine INT,
    IN p_price DECIMAL(6,2),
    IN p_score INT
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;
        INSERT INTO DrinkRecord(user_id, coffee_id, drink_date, quantity, cup_size, temperature, caffeine, price, taste_score)
        VALUES (p_user_id, p_coffee_id, p_date, p_quantity, p_cup_size, p_temperature, p_caffeine, p_price, p_score);
    COMMIT;
END;//

DELIMITER ;

-- ===================== 视图 =====================
CREATE VIEW v_coffee_ranking AS
SELECT
    c.coffee_id,
    c.name,
    c.shop,
    c.type,
    c.popularity,
    COUNT(dr.record_id) AS drink_count,
    ROUND(AVG(dr.taste_score), 1) AS avg_score
FROM Coffee c
LEFT JOIN DrinkRecord dr ON c.coffee_id = dr.coffee_id
GROUP BY c.coffee_id, c.name, c.shop, c.type, c.popularity
ORDER BY avg_score DESC, drink_count DESC;

-- 执行完本文件后请继续执行 insert_coffee.sql