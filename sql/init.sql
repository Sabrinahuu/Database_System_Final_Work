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
    price DECIMAL(6,2) DEFAULT NULL,        -- ← 移到 FOREIGN KEY 前面
    taste_score INT CHECK (taste_score BETWEEN 1 AND 10),  -- 用户评分
    FOREIGN KEY (user_id) REFERENCES `User`(user_id) ON DELETE CASCADE,
    FOREIGN KEY (coffee_id) REFERENCES Coffee(coffee_id) ON DELETE CASCADE
);

-- ===================== 7. 初始化咖啡数据 =====================
INSERT INTO Coffee(name, shop, type, popularity) VALUES
-- 星巴克
('美式咖啡', '星巴克', 'Espresso', 0),
('拿铁', '星巴克', 'Espresso', 0),
('馥芮白', '星巴克', 'Espresso', 0),
('冷萃咖啡', '星巴克', 'Cold Brew', 0),
('焦糖玛奇朵', '星巴克', 'Espresso', 0),
('摩卡', '星巴克', 'Espresso', 0),
('比利时黑巧拿铁', '星巴克', 'Espresso', 0),
('巴旦木拿铁', '星巴克', 'Espresso', 0),

-- 瑞幸
('生椰拿铁', '瑞幸', 'Espresso', 0),
('厚乳拿铁', '瑞幸', 'Espresso', 0),
('美式咖啡', '瑞幸', 'Espresso', 0),
('丝绒拿铁', '瑞幸', 'Espresso', 0),
('冰吸生椰', '瑞幸', 'Cold Brew', 0),
('小黄油拿铁', '瑞幸', 'Espresso', 0),
('精萃澳瑞白', '瑞幸', 'Espresso', 0),
('柚C美式', '瑞幸', 'Espresso', 0),

-- Manner
('手冲咖啡', 'Manner', 'Pour Over', 0),
('拿铁', 'Manner', 'Espresso', 0),
('美式', 'Manner', 'Espresso', 0),
('燕麦拿铁', 'Manner', 'Light Roast', 0),
('冷萃', 'Manner', 'Cold Brew', 0),
('烤坚果拿铁', 'Manner', 'Espresso', 0),
('咸芝士拿铁', 'Manner', 'Espresso', 0),
('干姜美式', 'Manner', 'Espresso', 0),

-- Grid
('单品手冲', 'Grid', 'Single Origin', 0),
('意式浓缩', 'Grid', 'Espresso', 0),
('拿铁', 'Grid', 'Espresso', 0),
('冷萃', 'Grid', 'Cold Brew', 0),
('白脱拿铁', 'Grid', 'Espresso', 0),
('咸奶萃', 'Grid', 'Cold Brew', 0),
('冷萃维也纳', 'Grid', 'Cold Brew', 0),
('罗马人美式', 'Grid', 'Espresso', 0),

-- M Stand
('燕麦拿铁', 'M Stand', 'Light Roast', 0),
('美式', 'M Stand', 'Espresso', 0),
('手冲', 'M Stand', 'Pour Over', 0),
('紫芋拿铁', 'M Stand', 'Espresso', 0),
('山核桃拿铁', 'M Stand', 'Espresso', 0),
('黑芝麻巴斯克拿铁', 'M Stand', 'Espresso', 0),
('话梅气泡美式', 'M Stand', 'Espresso', 0),
('冰摇黄杏美式', 'M Stand', 'Espresso', 0),

-- Peets
('Dirty', 'Peets', 'Espresso', 0),
('拿铁', 'Peets', 'Espresso', 0),
('焦糖烧拿铁', 'Peets', 'Espresso', 0),
('冷萃', 'Peets', 'Cold Brew', 0),
('芝士分子拿铁', 'Peets', 'Espresso', 0),
('三重玫瑰奶砖拿铁', 'Peets', 'Espresso', 0),
('卡布奇诺', 'Peets', 'Espresso', 0),
('澳洲小白', 'Peets', 'Espresso', 0),

-- Tims
('燕麦拿铁', 'Tims', 'Light Roast', 0),
('拿铁', 'Tims', 'Espresso', 0),
('美式', 'Tims', 'Espresso', 0),
('冷萃', 'Tims', 'Cold Brew', 0),
('水牛乳拿铁', 'Tims', 'Espresso', 0),
('山楂美式', 'Tims', 'Espresso', 0),
('玫瑰芝士浮云拿铁', 'Tims', 'Espresso', 0),
('澳白', 'Tims', 'Espresso', 0);


-- ===================== 8. 初始化口味标签 =====================
INSERT INTO FlavorTag(tag_name, tag_group, description) VALUES
('奶香', '口感', '带有牛奶、厚乳、燕麦奶等顺滑奶香感'),
('顺滑', '口感', '入口柔和，苦味不尖锐'),
('低苦', '口感', '苦味较低，适合新手或轻口味用户'),
('咖啡感', '强度', '咖啡本身风味明显'),
('浓郁', '强度', '整体风味厚重'),
('清爽', '口感', '口感轻盈，适合冰饮、冷萃或果味咖啡'),
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
('轻盈', '口感', '整体口感轻，负担感较低'),
('巧克力', '风味', '巧克力、可可、黑巧类风味'),
('芝士', '风味', '芝士、奶盖、咸奶油类风味'),
('黄油', '风味', '黄油、白脱、奶油类香气'),
('玫瑰', '风味', '玫瑰花香或花果香风味'),
('气泡感', '口感', '带有气泡水或清爽刺激口感'),
('话梅', '风味', '话梅、咸酸甜类风味'),
('姜味', '风味', '生姜、干姜等辛香风味'),
('芝麻', '风味', '黑芝麻、坚果谷物类香气'),
('芋香', '风味', '紫芋、芋泥、甜香类风味'),
('杏香', '风味', '黄杏、杏果类风味'),
('柑橘', '风味', '柚子、橙子、柑橘类酸甜风味');


-- ===================== 9. 给咖啡饮品绑定口味标签 =====================
-- 说明：
-- weight 表示该标签对这款饮品的代表程度。
-- 1.00 为普通匹配，1.20 / 1.30 为更强匹配。

INSERT INTO CoffeeFlavorTag(coffee_id, tag_id, weight)
SELECT c.coffee_id, t.tag_id,
    CASE
        WHEN t.tag_name IN ('奶香', '顺滑', '咖啡感', '浓郁', '清爽', '冰饮', '手冲层次') THEN 1.20
        WHEN t.tag_name IN ('椰香', '焦糖', '巧克力', '坚果', '芝士', '黄油', '玫瑰', '气泡感', '话梅', '姜味', '芝麻', '芋香', '杏香', '柑橘') THEN 1.30
        ELSE 1.00
    END
FROM Coffee c
JOIN FlavorTag t ON
    (
        -- 美式类
        (
            c.name IN ('美式咖啡', '美式', '罗马人美式')
            AND t.tag_name IN ('咖啡感', '浓郁', '高咖啡因')
        )

        -- 果味美式
        OR (
            c.name IN ('柚C美式')
            AND t.tag_name IN ('咖啡感', '清爽', '酸甜', '果香', '柑橘', '冰饮')
        )
        OR (
            c.name IN ('话梅气泡美式')
            AND t.tag_name IN ('咖啡感', '清爽', '酸甜', '话梅', '气泡感', '冰饮')
        )
        OR (
            c.name IN ('冰摇黄杏美式')
            AND t.tag_name IN ('咖啡感', '清爽', '酸甜', '果香', '杏香', '冰饮')
        )
        OR (
            c.name IN ('山楂美式')
            AND t.tag_name IN ('咖啡感', '清爽', '酸甜', '果香')
        )
        OR (
            c.name IN ('干姜美式')
            AND t.tag_name IN ('咖啡感', '浓郁', '姜味', '高咖啡因')
        )

        -- 基础拿铁类
        OR (
            c.name IN ('拿铁', '卡布奇诺', '澳白', '澳洲小白', '馥芮白', '精萃澳瑞白', 'Dirty')
            AND t.tag_name IN ('奶香', '顺滑', '低苦', '咖啡感', '浓郁')
        )

        -- 燕麦拿铁
        OR (
            c.name = '燕麦拿铁'
            AND t.tag_name IN ('奶香', '谷物香', '顺滑', '轻盈', '低苦')
        )

        -- 生椰类
        OR (
            c.name IN ('生椰拿铁', '冰吸生椰')
            AND t.tag_name IN ('奶香', '椰香', '顺滑', '低苦', '清爽', '冰饮')
        )

        -- 厚乳、水牛乳、丝绒类
        OR (
            c.name IN ('厚乳拿铁', '丝绒拿铁', '水牛乳拿铁')
            AND t.tag_name IN ('奶香', '顺滑', '浓郁', '低苦')
        )

        -- 焦糖类
        OR (
            c.name IN ('焦糖玛奇朵', '焦糖烧拿铁')
            AND t.tag_name IN ('奶香', '顺滑', '焦糖', '低苦', '浓郁')
        )

        -- 巧克力、摩卡类
        OR (
            c.name IN ('摩卡', '比利时黑巧拿铁')
            AND t.tag_name IN ('奶香', '顺滑', '巧克力', '浓郁', '低苦')
        )

        -- 坚果类
        OR (
            c.name IN ('巴旦木拿铁', '烤坚果拿铁', '山核桃拿铁')
            AND t.tag_name IN ('奶香', '顺滑', '坚果', '浓郁', '低苦')
        )

        -- 黄油、白脱类
        OR (
            c.name IN ('小黄油拿铁', '白脱拿铁')
            AND t.tag_name IN ('奶香', '顺滑', '黄油', '浓郁', '低苦')
        )

        -- 芝士类
        OR (
            c.name IN ('咸芝士拿铁', '芝士分子拿铁', '玫瑰芝士浮云拿铁')
            AND t.tag_name IN ('奶香', '顺滑', '芝士', '浓郁', '低苦')
        )

        -- 玫瑰类
        OR (
            c.name IN ('三重玫瑰奶砖拿铁', '玫瑰芝士浮云拿铁')
            AND t.tag_name IN ('奶香', '顺滑', '花香', '玫瑰', '低苦')
        )

        -- 紫芋、芝麻、巴斯克类
        OR (
            c.name = '紫芋拿铁'
            AND t.tag_name IN ('奶香', '顺滑', '芋香', '低苦')
        )
        OR (
            c.name = '黑芝麻巴斯克拿铁'
            AND t.tag_name IN ('奶香', '顺滑', '芝麻', '坚果', '浓郁', '低苦')
        )

        -- 冷萃类
        OR (
            c.name IN ('冷萃咖啡', '冷萃')
            AND t.tag_name IN ('清爽', '低苦', '冰饮', '咖啡感')
        )
        OR (
            c.name IN ('咸奶萃')
            AND t.tag_name IN ('奶香', '顺滑', '清爽', '冰饮', '低苦')
        )
        OR (
            c.name IN ('冷萃维也纳')
            AND t.tag_name IN ('奶香', '顺滑', '清爽', '冰饮', '浓郁')
        )

        -- 手冲、单品类
        OR (
            c.name IN ('手冲咖啡', '手冲', '单品手冲')
            AND t.tag_name IN ('果香', '花香', '酸甜', '手冲层次', '清爽')
        )

        -- 意式浓缩
        OR (
            c.name = '意式浓缩'
            AND t.tag_name IN ('咖啡感', '浓郁', '高咖啡因', '深烘')
        )
    );

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
