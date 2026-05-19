SET NAMES utf8mb4;

-- =====================================================
-- Coffee Recommendation System 初始化脚本
-- 功能：
-- 1. 建立用户、咖啡、饮用记录表
-- 2. 建立口味标签体系
-- 3. 初始化咖啡饮品与口味标签
-- 4. 支持排行榜与个性化推荐
-- 5. 用户新增饮用记录后自动更新咖啡热度和用户口味偏好
-- =====================================================

-- ===================== 清理旧对象，保证可重复执行 =====================
DROP VIEW IF EXISTS v_coffee_ranking;
DROP VIEW IF EXISTS v_coffee_tags;

DROP PROCEDURE IF EXISTS sp_add_drink_record;
DROP PROCEDURE IF EXISTS sp_recommend_coffee;

DROP TRIGGER IF EXISTS trg_check_score;
DROP TRIGGER IF EXISTS trg_update_popularity;

DROP TABLE IF EXISTS DrinkRecord;
DROP TABLE IF EXISTS UserPreference;
DROP TABLE IF EXISTS CoffeeFlavorTag;
DROP TABLE IF EXISTS FlavorTag;
DROP TABLE IF EXISTS `User`;
DROP TABLE IF EXISTS Coffee;

-- ===================== 1. 用户表 =====================
CREATE TABLE `User` (
    user_id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    password VARCHAR(100) NOT NULL,
    created_at DATETIME DEFAULT NOW()
);

-- ===================== 2. 咖啡表 =====================
CREATE TABLE Coffee (
    coffee_id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    shop VARCHAR(100) NOT NULL,
    type VARCHAR(50),
    popularity INT DEFAULT 0
);

-- ===================== 3. 口味标签表 =====================
CREATE TABLE FlavorTag (
    tag_id INT AUTO_INCREMENT PRIMARY KEY,
    tag_name VARCHAR(50) NOT NULL UNIQUE,
    tag_group VARCHAR(50),
    description VARCHAR(200)
);

-- ===================== 4. 咖啡饮品与口味标签关系表 =====================
CREATE TABLE CoffeeFlavorTag (
    coffee_id INT NOT NULL,
    tag_id INT NOT NULL,
    weight DECIMAL(4,2) DEFAULT 1.00,
    PRIMARY KEY (coffee_id, tag_id),
    FOREIGN KEY (coffee_id) REFERENCES Coffee(coffee_id) ON DELETE CASCADE,
    FOREIGN KEY (tag_id) REFERENCES FlavorTag(tag_id) ON DELETE CASCADE
);

-- ===================== 5. 用户偏好表 =====================
-- source:
-- register 表示注册时选择的初始偏好
-- history 表示根据后续饮用记录和评分学习得到的偏好
CREATE TABLE UserPreference (
    pref_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    tag_id INT NOT NULL,
    weight DECIMAL(4,2) DEFAULT 1.00,
    source VARCHAR(20) DEFAULT 'register',
    FOREIGN KEY (user_id) REFERENCES `User`(user_id) ON DELETE CASCADE,
    FOREIGN KEY (tag_id) REFERENCES FlavorTag(tag_id) ON DELETE CASCADE,
    UNIQUE KEY uk_user_tag (user_id, tag_id)
);

-- ===================== 6. 饮用记录表 =====================
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
    --用户对一次饮用记录的评分--
    taste_score INT CHECK (taste_score BETWEEN 1 AND 10),
    FOREIGN KEY (user_id) REFERENCES `User`(user_id) ON DELETE CASCADE,
    FOREIGN KEY (coffee_id) REFERENCES Coffee(coffee_id) ON DELETE CASCADE
);

-- ===================== 7. 初始化咖啡数据 =====================
INSERT INTO Coffee(name, shop, type, popularity) VALUES
('美式咖啡', '星巴克', 'Espresso', 0),
('拿铁', '星巴克', 'Espresso', 0),
('馥芮白', '星巴克', 'Espresso', 0),
('冷萃咖啡', '星巴克', 'Cold Brew', 0),
('燕麦拿铁', '星巴克', 'Light Roast', 0),
('生椰拿铁', '瑞幸', 'Espresso', 0),
('厚乳拿铁', '瑞幸', 'Espresso', 0),
('美式咖啡', '瑞幸', 'Espresso', 0),
('丝绒拿铁', '瑞幸', 'Espresso', 0),
('冰吸生椰', '瑞幸', 'Cold Brew', 0),
('手冲咖啡', 'Manner', 'Pour Over', 0),
('拿铁', 'Manner', 'Espresso', 0),
('美式', 'Manner', 'Espresso', 0),
('燕麦拿铁', 'Manner', 'Light Roast', 0),
('冷萃', 'Manner', 'Cold Brew', 0),
('单品手冲', 'Grid', 'Single Origin', 0),
('意式浓缩', 'Grid', 'Espresso', 0),
('拿铁', 'Grid', 'Espresso', 0),
('冷萃', 'Grid', 'Cold Brew', 0),
('燕麦拿铁', 'M Stand', 'Light Roast', 0),
('美式', 'M Stand', 'Espresso', 0),
('手冲', 'M Stand', 'Pour Over', 0),
('冷萃拿铁', 'M Stand', 'Cold Brew', 0),
('招牌浓缩', 'Peets', 'Espresso', 0),
('拿铁', 'Peets', 'Espresso', 0),
('黑眼龙', 'Peets', 'Dark Roast', 0),
('冷萃', 'Peets', 'Cold Brew', 0),
('招牌咖啡', 'Tims', 'Light Roast', 0),
('拿铁', 'Tims', 'Espresso', 0),
('美式', 'Tims', 'Espresso', 0),
('冷萃', 'Tims', 'Cold Brew', 0);

-- ===================== 8. 初始化口味标签 =====================
INSERT INTO FlavorTag(tag_name, tag_group, description) VALUES
('奶香', '口感', '带有牛奶、厚乳、燕麦奶等顺滑奶香感'),
('顺滑', '口感', '入口柔和，苦味不尖锐'),
('低苦', '口感', '苦味较低，适合新手或轻口味用户'),
('咖啡感', '强度', '咖啡本身风味明显'),
('浓郁', '强度', '整体风味厚重'),
('清爽', '口感', '口感轻盈，适合冰饮或冷萃'),
('酸甜', '风味', '带有明亮酸甜感'),
('果香', '风味', '有水果类风味倾向'),
('花香', '风味', '有花香、茶感等细腻风味'),
('坚果', '风味', '坚果、烘烤类香气'),
('焦糖', '风味', '焦糖、甜香、烘焙甜感'),
('椰香', '风味', '生椰、椰乳相关风味'),
('谷物香', '风味', '燕麦、麦香、谷物感'),
('深烘', '烘焙', '深烘焙、苦香明显'),
('冰饮', '温度', '适合冰饮或冷饮场景'),
('高咖啡因', '强度', '咖啡因含量相对较高'),
('手冲层次', '风味', '手冲或单品咖啡常见的层次感'),
('轻盈', '口感', '整体口感轻，负担感较低');

-- ===================== 9. 给咖啡饮品绑定口味标签 =====================
-- 说明：
-- weight 表示该标签对这款饮品的代表程度。
-- 1.00 为普通匹配，1.20 / 1.30 为更强匹配。

-- 星巴克
INSERT INTO CoffeeFlavorTag(coffee_id, tag_id, weight)
SELECT c.coffee_id, t.tag_id,
    CASE
        WHEN t.tag_name IN ('咖啡感', '浓郁') THEN 1.20
        ELSE 1.00
    END
FROM Coffee c
JOIN FlavorTag t ON t.tag_name IN ('咖啡感', '浓郁', '高咖啡因')
WHERE c.name = '美式咖啡' AND c.shop = '星巴克';

INSERT INTO CoffeeFlavorTag(coffee_id, tag_id, weight)
SELECT c.coffee_id, t.tag_id,
    CASE
        WHEN t.tag_name IN ('奶香', '顺滑') THEN 1.20
        ELSE 1.00
    END
FROM Coffee c
JOIN FlavorTag t ON t.tag_name IN ('奶香', '顺滑', '低苦', '咖啡感')
WHERE c.name = '拿铁' AND c.shop = '星巴克';

INSERT INTO CoffeeFlavorTag(coffee_id, tag_id, weight)
SELECT c.coffee_id, t.tag_id,
    CASE
        WHEN t.tag_name IN ('奶香', '顺滑') THEN 1.30
        ELSE 1.00
    END
FROM Coffee c
JOIN FlavorTag t ON t.tag_name IN ('奶香', '顺滑', '浓郁', '低苦')
WHERE c.name = '馥芮白' AND c.shop = '星巴克';

INSERT INTO CoffeeFlavorTag(coffee_id, tag_id, weight)
SELECT c.coffee_id, t.tag_id,
    CASE
        WHEN t.tag_name IN ('清爽', '冰饮') THEN 1.20
        ELSE 1.00
    END
FROM Coffee c
JOIN FlavorTag t ON t.tag_name IN ('清爽', '低苦', '冰饮', '咖啡感')
WHERE c.name = '冷萃咖啡' AND c.shop = '星巴克';

INSERT INTO CoffeeFlavorTag(coffee_id, tag_id, weight)
SELECT c.coffee_id, t.tag_id,
    CASE
        WHEN t.tag_name IN ('谷物香', '顺滑') THEN 1.20
        ELSE 1.00
    END
FROM Coffee c
JOIN FlavorTag t ON t.tag_name IN ('奶香', '谷物香', '顺滑', '轻盈', '低苦')
WHERE c.name = '燕麦拿铁' AND c.shop = '星巴克';

-- 瑞幸
INSERT INTO CoffeeFlavorTag(coffee_id, tag_id, weight)
SELECT c.coffee_id, t.tag_id,
    CASE
        WHEN t.tag_name IN ('椰香', '奶香') THEN 1.30
        ELSE 1.00
    END
FROM Coffee c
JOIN FlavorTag t ON t.tag_name IN ('奶香', '椰香', '顺滑', '低苦')
WHERE c.name = '生椰拿铁' AND c.shop = '瑞幸';

INSERT INTO CoffeeFlavorTag(coffee_id, tag_id, weight)
SELECT c.coffee_id, t.tag_id,
    CASE
        WHEN t.tag_name IN ('奶香', '浓郁') THEN 1.30
        ELSE 1.00
    END
FROM Coffee c
JOIN FlavorTag t ON t.tag_name IN ('奶香', '顺滑', '浓郁', '低苦')
WHERE c.name = '厚乳拿铁' AND c.shop = '瑞幸';

INSERT INTO CoffeeFlavorTag(coffee_id, tag_id, weight)
SELECT c.coffee_id, t.tag_id,
    CASE
        WHEN t.tag_name IN ('咖啡感', '浓郁') THEN 1.20
        ELSE 1.00
    END
FROM Coffee c
JOIN FlavorTag t ON t.tag_name IN ('咖啡感', '浓郁', '高咖啡因')
WHERE c.name = '美式咖啡' AND c.shop = '瑞幸';

INSERT INTO CoffeeFlavorTag(coffee_id, tag_id, weight)
SELECT c.coffee_id, t.tag_id,
    CASE
        WHEN t.tag_name IN ('奶香', '顺滑') THEN 1.20
        ELSE 1.00
    END
FROM Coffee c
JOIN FlavorTag t ON t.tag_name IN ('奶香', '顺滑', '焦糖', '低苦')
WHERE c.name = '丝绒拿铁' AND c.shop = '瑞幸';

INSERT INTO CoffeeFlavorTag(coffee_id, tag_id, weight)
SELECT c.coffee_id, t.tag_id,
    CASE
        WHEN t.tag_name IN ('椰香', '清爽', '冰饮') THEN 1.20
        ELSE 1.00
    END
FROM Coffee c
JOIN FlavorTag t ON t.tag_name IN ('椰香', '清爽', '冰饮', '低苦')
WHERE c.name = '冰吸生椰' AND c.shop = '瑞幸';

-- Manner
INSERT INTO CoffeeFlavorTag(coffee_id, tag_id, weight)
SELECT c.coffee_id, t.tag_id,
    CASE
        WHEN t.tag_name IN ('果香', '手冲层次') THEN 1.20
        ELSE 1.00
    END
FROM Coffee c
JOIN FlavorTag t ON t.tag_name IN ('果香', '花香', '酸甜', '手冲层次', '清爽')
WHERE c.name = '手冲咖啡' AND c.shop = 'Manner';

INSERT INTO CoffeeFlavorTag(coffee_id, tag_id, weight)
SELECT c.coffee_id, t.tag_id,
    CASE
        WHEN t.tag_name IN ('奶香', '顺滑') THEN 1.20
        ELSE 1.00
    END
FROM Coffee c
JOIN FlavorTag t ON t.tag_name IN ('奶香', '顺滑', '低苦', '咖啡感')
WHERE c.name = '拿铁' AND c.shop = 'Manner';

INSERT INTO CoffeeFlavorTag(coffee_id, tag_id, weight)
SELECT c.coffee_id, t.tag_id,
    CASE
        WHEN t.tag_name IN ('咖啡感', '浓郁') THEN 1.20
        ELSE 1.00
    END
FROM Coffee c
JOIN FlavorTag t ON t.tag_name IN ('咖啡感', '浓郁', '高咖啡因')
WHERE c.name = '美式' AND c.shop = 'Manner';

INSERT INTO CoffeeFlavorTag(coffee_id, tag_id, weight)
SELECT c.coffee_id, t.tag_id,
    CASE
        WHEN t.tag_name IN ('谷物香', '顺滑') THEN 1.20
        ELSE 1.00
    END
FROM Coffee c
JOIN FlavorTag t ON t.tag_name IN ('奶香', '谷物香', '顺滑', '轻盈', '低苦')
WHERE c.name = '燕麦拿铁' AND c.shop = 'Manner';

INSERT INTO CoffeeFlavorTag(coffee_id, tag_id, weight)
SELECT c.coffee_id, t.tag_id,
    CASE
        WHEN t.tag_name IN ('清爽', '冰饮') THEN 1.20
        ELSE 1.00
    END
FROM Coffee c
JOIN FlavorTag t ON t.tag_name IN ('清爽', '低苦', '冰饮', '咖啡感')
WHERE c.name = '冷萃' AND c.shop = 'Manner';

-- Grid
INSERT INTO CoffeeFlavorTag(coffee_id, tag_id, weight)
SELECT c.coffee_id, t.tag_id,
    CASE
        WHEN t.tag_name IN ('果香', '花香', '手冲层次') THEN 1.20
        ELSE 1.00
    END
FROM Coffee c
JOIN FlavorTag t ON t.tag_name IN ('果香', '花香', '酸甜', '手冲层次', '清爽')
WHERE c.name = '单品手冲' AND c.shop = 'Grid';

INSERT INTO CoffeeFlavorTag(coffee_id, tag_id, weight)
SELECT c.coffee_id, t.tag_id,
    CASE
        WHEN t.tag_name IN ('咖啡感', '浓郁', '高咖啡因') THEN 1.20
        ELSE 1.00
    END
FROM Coffee c
JOIN FlavorTag t ON t.tag_name IN ('咖啡感', '浓郁', '高咖啡因')
WHERE c.name = '意式浓缩' AND c.shop = 'Grid';

INSERT INTO CoffeeFlavorTag(coffee_id, tag_id, weight)
SELECT c.coffee_id, t.tag_id,
    CASE
        WHEN t.tag_name IN ('奶香', '顺滑') THEN 1.20
        ELSE 1.00
    END
FROM Coffee c
JOIN FlavorTag t ON t.tag_name IN ('奶香', '顺滑', '低苦', '咖啡感')
WHERE c.name = '拿铁' AND c.shop = 'Grid';

INSERT INTO CoffeeFlavorTag(coffee_id, tag_id, weight)
SELECT c.coffee_id, t.tag_id,
    CASE
        WHEN t.tag_name IN ('清爽', '冰饮') THEN 1.20
        ELSE 1.00
    END
FROM Coffee c
JOIN FlavorTag t ON t.tag_name IN ('清爽', '低苦', '冰饮', '咖啡感')
WHERE c.name = '冷萃' AND c.shop = 'Grid';

-- M Stand
INSERT INTO CoffeeFlavorTag(coffee_id, tag_id, weight)
SELECT c.coffee_id, t.tag_id,
    CASE
        WHEN t.tag_name IN ('谷物香', '顺滑') THEN 1.20
        ELSE 1.00
    END
FROM Coffee c
JOIN FlavorTag t ON t.tag_name IN ('奶香', '谷物香', '顺滑', '轻盈', '低苦')
WHERE c.name = '燕麦拿铁' AND c.shop = 'M Stand';

INSERT INTO CoffeeFlavorTag(coffee_id, tag_id, weight)
SELECT c.coffee_id, t.tag_id,
    CASE
        WHEN t.tag_name IN ('咖啡感', '浓郁') THEN 1.20
        ELSE 1.00
    END
FROM Coffee c
JOIN FlavorTag t ON t.tag_name IN ('咖啡感', '浓郁', '高咖啡因')
WHERE c.name = '美式' AND c.shop = 'M Stand';

INSERT INTO CoffeeFlavorTag(coffee_id, tag_id, weight)
SELECT c.coffee_id, t.tag_id,
    CASE
        WHEN t.tag_name IN ('果香', '手冲层次') THEN 1.20
        ELSE 1.00
    END
FROM Coffee c
JOIN FlavorTag t ON t.tag_name IN ('果香', '花香', '酸甜', '手冲层次', '清爽')
WHERE c.name = '手冲' AND c.shop = 'M Stand';

INSERT INTO CoffeeFlavorTag(coffee_id, tag_id, weight)
SELECT c.coffee_id, t.tag_id,
    CASE
        WHEN t.tag_name IN ('奶香', '清爽', '冰饮') THEN 1.20
        ELSE 1.00
    END
FROM Coffee c
JOIN FlavorTag t ON t.tag_name IN ('奶香', '顺滑', '清爽', '冰饮', '低苦')
WHERE c.name = '冷萃拿铁' AND c.shop = 'M Stand';

-- Peets
INSERT INTO CoffeeFlavorTag(coffee_id, tag_id, weight)
SELECT c.coffee_id, t.tag_id,
    CASE
        WHEN t.tag_name IN ('咖啡感', '浓郁') THEN 1.20
        ELSE 1.00
    END
FROM Coffee c
JOIN FlavorTag t ON t.tag_name IN ('咖啡感', '浓郁', '高咖啡因')
WHERE c.name = '招牌浓缩' AND c.shop = 'Peets';

INSERT INTO CoffeeFlavorTag(coffee_id, tag_id, weight)
SELECT c.coffee_id, t.tag_id,
    CASE
        WHEN t.tag_name IN ('奶香', '顺滑') THEN 1.20
        ELSE 1.00
    END
FROM Coffee c
JOIN FlavorTag t ON t.tag_name IN ('奶香', '顺滑', '低苦', '咖啡感')
WHERE c.name = '拿铁' AND c.shop = 'Peets';

INSERT INTO CoffeeFlavorTag(coffee_id, tag_id, weight)
SELECT c.coffee_id, t.tag_id,
    CASE
        WHEN t.tag_name IN ('深烘', '浓郁', '高咖啡因') THEN 1.30
        ELSE 1.00
    END
FROM Coffee c
JOIN FlavorTag t ON t.tag_name IN ('深烘', '浓郁', '咖啡感', '高咖啡因')
WHERE c.name = '黑眼龙' AND c.shop = 'Peets';

INSERT INTO CoffeeFlavorTag(coffee_id, tag_id, weight)
SELECT c.coffee_id, t.tag_id,
    CASE
        WHEN t.tag_name IN ('清爽', '冰饮') THEN 1.20
        ELSE 1.00
    END
FROM Coffee c
JOIN FlavorTag t ON t.tag_name IN ('清爽', '低苦', '冰饮', '咖啡感')
WHERE c.name = '冷萃' AND c.shop = 'Peets';

-- Tims
INSERT INTO CoffeeFlavorTag(coffee_id, tag_id, weight)
SELECT c.coffee_id, t.tag_id,
    CASE
        WHEN t.tag_name IN ('轻盈', '顺滑') THEN 1.20
        ELSE 1.00
    END
FROM Coffee c
JOIN FlavorTag t ON t.tag_name IN ('轻盈', '顺滑', '低苦', '坚果', '焦糖')
WHERE c.name = '招牌咖啡' AND c.shop = 'Tims';

INSERT INTO CoffeeFlavorTag(coffee_id, tag_id, weight)
SELECT c.coffee_id, t.tag_id,
    CASE
        WHEN t.tag_name IN ('奶香', '顺滑') THEN 1.20
        ELSE 1.00
    END
FROM Coffee c
JOIN FlavorTag t ON t.tag_name IN ('奶香', '顺滑', '低苦', '咖啡感')
WHERE c.name = '拿铁' AND c.shop = 'Tims';

INSERT INTO CoffeeFlavorTag(coffee_id, tag_id, weight)
SELECT c.coffee_id, t.tag_id,
    CASE
        WHEN t.tag_name IN ('咖啡感', '浓郁') THEN 1.20
        ELSE 1.00
    END
FROM Coffee c
JOIN FlavorTag t ON t.tag_name IN ('咖啡感', '浓郁', '高咖啡因')
WHERE c.name = '美式' AND c.shop = 'Tims';

INSERT INTO CoffeeFlavorTag(coffee_id, tag_id, weight)
SELECT c.coffee_id, t.tag_id,
    CASE
        WHEN t.tag_name IN ('清爽', '冰饮') THEN 1.20
        ELSE 1.00
    END
FROM Coffee c
JOIN FlavorTag t ON t.tag_name IN ('清爽', '低苦', '冰饮', '咖啡感')
WHERE c.name = '冷萃' AND c.shop = 'Tims';

-- ===================== 10. 触发器 =====================
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

-- ===================== 11. 新增饮用记录并更新用户偏好 =====================
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
    DECLARE v_delta DECIMAL(4,2);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF p_score < 1 OR p_score > 10 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Score must be between 1 and 10';
    END IF;

    SET v_delta = CASE
        WHEN p_score >= 9 THEN 0.40
        WHEN p_score >= 8 THEN 0.30
        WHEN p_score >= 6 THEN 0.10
        WHEN p_score >= 4 THEN -0.05
        ELSE -0.20
    END;

    START TRANSACTION;

        INSERT INTO DrinkRecord(
            user_id,
            coffee_id,
            drink_date,
            quantity,
            cup_size,
            temperature,
            caffeine,
            price,
            taste_score
        )
        VALUES (
            p_user_id,
            p_coffee_id,
            p_date,
            p_quantity,
            p_cup_size,
            p_temperature,
            p_caffeine,
            p_price,
            p_score
        );

        -- 根据本次饮用评分更新用户对该饮品相关标签的偏好权重
        -- 高分增加权重，低分降低权重，权重范围限制在 0 到 5
        INSERT INTO UserPreference(user_id, tag_id, weight, source)
SELECT
    p_user_id,
    cft.tag_id,
    v_delta * cft.weight,
    'history'
FROM CoffeeFlavorTag cft
WHERE cft.coffee_id = p_coffee_id
ON DUPLICATE KEY UPDATE
    weight = LEAST(5.00, GREATEST(0.00, weight + VALUES(weight))),
    source = IF(source = 'register', 'register', 'history');

    COMMIT;
END;//

DELIMITER ;

-- ===================== 12. 个性化推荐存储过程 =====================
DELIMITER //

CREATE PROCEDURE sp_recommend_coffee(IN p_user_id INT)
BEGIN
    SELECT
        c.coffee_id,
        c.name,
        c.shop,
        c.type,
        GROUP_CONCAT(DISTINCT ft.tag_name ORDER BY ft.tag_name SEPARATOR ', ') AS flavor_tags,
        ROUND(
            COALESCE(SUM(up.weight * cft.weight), 0)
            + c.popularity * 0.05
            + COALESCE(AVG(dr_all.taste_score), 0) * 0.10,
            2
        ) AS recommend_score
    FROM Coffee c
    JOIN CoffeeFlavorTag cft ON c.coffee_id = cft.coffee_id
    JOIN FlavorTag ft ON cft.tag_id = ft.tag_id
    LEFT JOIN UserPreference up
        ON cft.tag_id = up.tag_id
        AND up.user_id = p_user_id
    LEFT JOIN DrinkRecord dr_all
        ON c.coffee_id = dr_all.coffee_id
    WHERE c.coffee_id NOT IN (
        SELECT coffee_id
        FROM DrinkRecord
        WHERE user_id = p_user_id
    )
    GROUP BY c.coffee_id, c.name, c.shop, c.type, c.popularity
    ORDER BY recommend_score DESC, c.popularity DESC
    LIMIT 10;
END;//

DELIMITER ;

-- ===================== 13. 视图：咖啡排行榜 =====================
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

-- ===================== 14. 视图：咖啡标签展示 =====================
CREATE VIEW v_coffee_tags AS
SELECT
    c.coffee_id,
    c.name,
    c.shop,
    c.type,
    GROUP_CONCAT(ft.tag_name ORDER BY ft.tag_name SEPARATOR ', ') AS flavor_tags
FROM Coffee c
LEFT JOIN CoffeeFlavorTag cft ON c.coffee_id = cft.coffee_id
LEFT JOIN FlavorTag ft ON cft.tag_id = ft.tag_id
GROUP BY c.coffee_id, c.name, c.shop, c.type;
