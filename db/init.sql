SET NAMES utf8;

DROP DATABASE `opencloset`;
CREATE DATABASE `opencloset`;
USE `opencloset`;

--
-- user
--

CREATE TABLE `user` (
  `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `name`        VARCHAR(32) NOT NULL, -- realname
  `email`       VARCHAR(128) DEFAULT NULL,
  `password`    CHAR(50) DEFAULT NULL COMMENT 'first 40 length for digest, after 10 length for salt(random)',
  `phone`       VARCHAR(16) DEFAULT NULL COMMENT 'regex: 01\d{8,9}',
  `gender`      INT DEFAULT NULL COMMENT '1: male, 2: female',
  `age`         INT DEFAULT NULL,
  `address`     VARCHAR(255) DEFAULT NULL,
  `create_date` DATETIME DEFAULT NULL,

  PRIMARY KEY (`id`),
  UNIQUE KEY (`email`),
  UNIQUE KEY (`phone`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- donor 기증자
--

CREATE TABLE `donor` (
  `id`           INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `user_id`      INT UNSIGNED DEFAULT NULL,
  `donation_msg` TEXT DEFAULT NULL,
  `comment`      TEXT DEFAULT NULL,
  `create_date`  DATETIME DEFAULT NULL,

  PRIMARY KEY (`id`),
  UNIQUE KEY (`user_id`),
  CONSTRAINT `fk_donor1` FOREIGN KEY (`user_id`) REFERENCES `user` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- guest
--

CREATE TABLE `guest` (
  `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `user_id`     INT UNSIGNED NOT NULL,
  `bust`        INT NOT NULL,     -- 가슴둘레(cm)
  `waist`       INT NOT NULL,     -- 허리둘레(cm)
  `arm`         INT DEFAULT NULL, -- 팔길이(cm)
  `length`      INT DEFAULT NULL, -- 기장(cm)
  `height`      INT DEFAULT NULL, -- cm
  `weight`      INT DEFAULT NULL, -- kg
  `purpose`     VARCHAR(32),
  `domain`      VARCHAR(64),
  `create_date` DATETIME DEFAULT NULL,
  `visit_date`  DATETIME DEFAULT NULL, -- latest visit
  `target_date` DATETIME DEFAULT NULL, -- 착용일

  PRIMARY KEY (`id`),
  UNIQUE KEY (`user_id`),
  CONSTRAINT `fk_guest1` FOREIGN KEY (`user_id`) REFERENCES `user` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- status
--

CREATE TABLE `status` (
  `id`   INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `name` VARCHAR (64) NOT NULL,

  PRIMARY KEY (`id`),
  UNIQUE KEY (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

INSERT INTO `status` (`id`, `name`)
  VALUES
    (1,  '대여가능'),
    (2,  '대여중'),
    (3,  '대여불가'),
    (4,  '예약'),
    (5,  '세탁'),
    (6,  '수선'),
    (7,  '분실'),
    (8,  '폐기'),
    (9,  '반납'),
    (10, '부분반납'),
    (11, '반납배송중')
    ;

--
-- cloth
--

CREATE TABLE `cloth` (
  `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,

  `no`          VARCHAR(64) NOT NULL,     -- 바코드 품번
  `bust`        INT         DEFAULT NULL, -- 가슴 둘레(cm)
  `waist`       INT         DEFAULT NULL, -- 허리 둘레(cm)
  `hip`         INT         DEFAULT NULL, -- 엉덩이 둘레(cm)
  `arm`         INT         DEFAULT NULL, -- 팔 길이(cm)
  `thigh`       INT         DEFAULT NULL, -- 허벅지 둘레(cm)
  `length`      INT         DEFAULT NULL, -- 기장(cm)
  `foot`        INT         DEFAULT NULL, -- 발 크기(mm)
  `color`       VARCHAR(32) DEFAULT NULL,
  `gender`      INT         DEFAULT NULL, -- 1: man, 2: woman, 3: unisex
  `category`    VARCHAR(32) NOT NULL,     -- 종류
  `price`       INT DEFAULT 0,            -- 대여 가격

  `top_id`      INT UNSIGNED DEFAULT NULL,
  `bottom_id`   INT UNSIGNED DEFAULT NULL,
  `donor_id`    INT UNSIGNED DEFAULT NULL,
  `status_id`   INT UNSIGNED DEFAULT 1,

  `compatible_code` VARCHAR(32) DEFAULT NULL,

  PRIMARY KEY (`id`),
  UNIQUE KEY (`no`),
  INDEX (`bust`),
  INDEX (`waist`),
  INDEX (`hip`),
  INDEX (`arm`),
  INDEX (`thigh`),
  INDEX (`length`),
  INDEX (`category`),
  CONSTRAINT `fk_cloth1` FOREIGN KEY (`top_id`)    REFERENCES `cloth`  (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_cloth2` FOREIGN KEY (`bottom_id`) REFERENCES `cloth`  (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_cloth3` FOREIGN KEY (`donor_id`)  REFERENCES `donor`  (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_cloth4` FOREIGN KEY (`status_id`) REFERENCES `status` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- satisfaction
--

CREATE TABLE `satisfaction` (
  -- 1: 매우작음, 2: 매우큼, 3: 작음, 4: 큼, 5: 맞음
  -- 높을 수록 좋은거(작은거 보단 큰게 낫다 by aanoaa)
  -- 쟈켓만 해당함

  `guest_id`    INT UNSIGNED NOT NULL,
  `cloth_id`    INT UNSIGNED NOT NULL,
  `bust`        INT DEFAULT NULL,
  `waist`       INT DEFAULT NULL,
  `arm`         INT DEFAULT NULL,
  `top_fit`     INT DEFAULT NULL,
  `bottom_fit`  INT DEFAULT NULL,
  `create_date` DATETIME DEFAULT NULL,

  PRIMARY KEY (`guest_id`, `cloth_id`),
  CONSTRAINT `fk_satisfaction1` FOREIGN KEY (`guest_id`) REFERENCES `guest` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_satisfaction2` FOREIGN KEY (`cloth_id`) REFERENCES `cloth` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- order
--

CREATE TABLE `order` (
  `id`               INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `guest_id`         INT UNSIGNED NOT NULL,
  `status_id`        INT UNSIGNED DEFAULT NULL,
  `rental_date`      DATETIME DEFAULT NULL,
  `target_date`      DATETIME DEFAULT NULL,
  `return_date`      DATETIME DEFAULT NULL,
  `return_method`    VARCHAR(32) DEFAULT NULL,
  `payment_method`   VARCHAR(32) DEFAULT NULL,
  `price`            INT DEFAULT 0,
  `discount`         INT DEFAULT 0,
  `late_fee`         INT DEFAULT 0,
  `l_discount`       INT DEFAULT 0, -- late_fee discount
  `l_payment_method` VARCHAR(32) DEFAULT NULL,
  `staff_name`       VARCHAR(32) DEFAULT NULL,
  `comment`          TEXT DEFAULT NULL,

  -- guest info
  `purpose`          VARCHAR(32),
  `age`              INT DEFAULT NULL,
  `bust`             INT DEFAULT NULL,
  `waist`            INT DEFAULT NULL,
  `arm`              INT DEFAULT NULL,
  `length`           INT DEFAULT NULL,

  PRIMARY KEY (`id`),
  CONSTRAINT `fk_order1` FOREIGN KEY (`guest_id`) REFERENCES `guest` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_order2` FOREIGN KEY (`status_id`) REFERENCES `status` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- cloth_order
--

CREATE TABLE `cloth_order` (
  `cloth_id` INT UNSIGNED NOT NULL,
  `order_id`  INT UNSIGNED NOT NULL,

  PRIMARY KEY (`cloth_id`, `order_id`),
  CONSTRAINT `fk_cloth_order1` FOREIGN KEY (`cloth_id`) REFERENCES `cloth` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_cloth_order2` FOREIGN KEY (`order_id`) REFERENCES `order` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- donor_cloth
--

CREATE TABLE `donor_cloth` (
  `donor_id`      INT UNSIGNED NOT NULL,
  `cloth_id`      INT UNSIGNED NOT NULL,
  `comment`       TEXT DEFAULT NULL,
  `donation_date` DATETIME DEFAULT NULL,

  PRIMARY KEY (`donor_id`, `cloth_id`),
  CONSTRAINT `fk_donor_cloth1` FOREIGN KEY (`donor_id`) REFERENCES `donor` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_donor_cloth2` FOREIGN KEY (`cloth_id`) REFERENCES `cloth` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `short_message` (
  `id`        INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `from`      VARCHAR(32) NOT NULL,
  `to`        VARCHAR(32) NOT NULL,
  `msg`       VARCHAR(128) DEFAULT NULL,
  `sent_date` DATETIME DEFAULT NULL,
  PRIMARY KEY (`id`)
);
