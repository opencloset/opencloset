SET NAMES utf8;

DROP DATABASE `opencloset`;
CREATE DATABASE `opencloset`;
USE `opencloset`;

--
-- donor 기증자
--

CREATE TABLE `donor` (
  `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `name`        VARCHAR(32) NOT NULL,
  `email`       VARCHAR(128) DEFAULT NULL,
  `phone`       VARCHAR(16) DEFAULT NULL COMMENT 'regex: [0-9]{10,11}',
  `comment`     TEXT DEFAULT NULL,
  `create_date` DATETIME DEFAULT NULL,

  PRIMARY KEY (`id`),
  UNIQUE KEY (`email`),
  UNIQUE KEY (`phone`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- guest
--

CREATE TABLE `guest` (
  `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `name`        VARCHAR(32) NOT NULL,
  `email`       VARCHAR(128) DEFAULT NULL,
  `phone`       VARCHAR(16) DEFAULT NULL COMMENT 'regex: [0-9]{10,11}',
  `gender`      INT DEFAULT NULL COMMENT '0: male, 1: female',
  `address`     VARCHAR(255) DEFAULT NULL,
  `age`         INT DEFAULT NULL,
  `purpose`     VARCHAR(32),

  `chest`       INT NOT NULL,     -- 가슴둘레(cm)
  `waist`       INT NOT NULL,     -- 허리둘레(cm)
  `arm`         INT DEFAULT NULL, -- 팔길이(cm)
  `pants_len`   INT DEFAULT NULL, -- 기장(cm)
  `height`      INT DEFAULT NULL, -- cm
  `weight`      INT DEFAULT NULL, -- kg
  `create_date` DATETIME DEFAULT NULL,
  `visit_date`  DATETIME DEFAULT NULL, -- latest visit

  PRIMARY KEY (`id`),
  UNIQUE KEY (`email`),
  UNIQUE KEY (`phone`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- category
--

CREATE TABLE `category` (
  `id`    INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `name`  VARCHAR (64) NOT NULL,
  `price` INT DEFAULT 0,

  PRIMARY KEY (`id`),
  UNIQUE KEY (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

INSERT INTO `category` (`id`, `name`, `price`) VALUES (1, 'Jacket', 10000), (2, 'Pants', 10000), (3, 'Shirts', 5000), (4, 'Shoes', 5000), (5, 'Hat', 0), (6, 'Tie', 0);

--
-- status
--

CREATE TABLE `status` (
  `id`   INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `name` VARCHAR (64) NOT NULL,

  PRIMARY KEY (`id`),
  UNIQUE KEY (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

INSERT INTO `status` (`id`, `name`) VALUES (1, '대여가능'), (2, '대여중'), (3, '세탁'), (4, '수선'), (5, '대여불가'), (6, '연체중'), (7, '분실'), (8, '반납');

--
-- clothe
--

CREATE TABLE `clothe` (
  `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `no`          VARCHAR(64) NOT NULL,  -- 바코드 품번
  `chest`       INT DEFAULT NULL,
  `waist`       INT DEFAULT NULL,
  `arm`         INT DEFAULT NULL, -- 팔길이(cm)
  `pants_len`   INT DEFAULT NULL, -- 기장(cm)

  `category_id` INT UNSIGNED NOT NULL,
  `top_id`      INT UNSIGNED DEFAULT NULL,
  `bottom_id`   INT UNSIGNED DEFAULT NULL,
  `donor_id`    INT UNSIGNED DEFAULT NULL,
  `status_id`   INT UNSIGNED DEFAULT 1,

  PRIMARY KEY (`id`),
  UNIQUE KEY (`no`),
  INDEX (`chest`),
  INDEX (`waist`),
  INDEX (`arm`),
  INDEX (`pants_len`),
  CONSTRAINT `fk_clothe1` FOREIGN KEY (`category_id`) REFERENCES `category` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_clothe2` FOREIGN KEY (`top_id`) REFERENCES `clothe` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_clothe3` FOREIGN KEY (`bottom_id`) REFERENCES `clothe` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_clothe4` FOREIGN KEY (`donor_id`) REFERENCES `donor` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_clothe5` FOREIGN KEY (`status_id`) REFERENCES `status` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- satisfaction
--

CREATE TABLE `satisfaction` (
  -- 1: 매우작음, 2: 매우큼, 3: 작음, 4: 큼, 5: 맞음
  -- 높을 수록 좋은거(작은거 보단 큰게 낫다 by aanoaa)
  -- 쟈켓만 해당함

  `guest_id`    INT UNSIGNED NOT NULL,
  `clothe_id`   INT UNSIGNED NOT NULL,
  `chest`       INT DEFAULT NULL,
  `waist`       INT DEFAULT NULL,
  `arm`         INT DEFAULT NULL,
  `top_fit`     INT DEFAULT NULL,
  `bottom_fit`  INT DEFAULT NULL,
  `create_date` DATETIME DEFAULT NULL,

  PRIMARY KEY (`guest_id`, `clothe_id`),
  CONSTRAINT `fk_satisfaction1` FOREIGN KEY (`guest_id`) REFERENCES `guest` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_satisfaction2` FOREIGN KEY (`clothe_id`) REFERENCES `clothe` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- order
--

CREATE TABLE `order` (
  `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `guest_id`    INT UNSIGNED NOT NULL,
  `status_id`   INT UNSIGNED DEFAULT NULL,

  `rental_date`   DATETIME DEFAULT NULL,
  `target_date`   DATETIME DEFAULT NULL,
  `return_date`   DATETIME DEFAULT NULL,
  `return_method` VARCHAR(32) DEFAULT NULL,
  `price`         INT DEFAULT 0,
  `discount`      INT DEFAULT 0,
  `late_fee`      INT DEFAULT 0,
  `l_discount`    INT DEFAULT 0, -- late_fee discount
  `comment`       TEXT DEFAULT NULL,

  PRIMARY KEY (`id`),
  CONSTRAINT `fk_order1` FOREIGN KEY (`guest_id`) REFERENCES `guest` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_order2` FOREIGN KEY (`status_id`) REFERENCES `status` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- clothe_order
--

CREATE TABLE `clothe_order` (
  `clothe_id` INT UNSIGNED NOT NULL,
  `order_id`   INT UNSIGNED NOT NULL,

  PRIMARY KEY (`clothe_id`, `order_id`),
  CONSTRAINT `fk_clothe_order1` FOREIGN KEY (`clothe_id`) REFERENCES `clothe` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_clothe_order2` FOREIGN KEY (`order_id`) REFERENCES `order` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- donor_clothe
--

CREATE TABLE `donor_clothe` (
  `donor_id`      INT UNSIGNED NOT NULL,
  `clothe_id`    INT UNSIGNED NOT NULL,
  `comment`       TEXT DEFAULT NULL,
  `donation_date` DATETIME DEFAULT NULL,

  PRIMARY KEY (`donor_id`, `clothe_id`),
  CONSTRAINT `fk_donor_clothe1` FOREIGN KEY (`donor_id`) REFERENCES `donor` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_donor_clothe2` FOREIGN KEY (`clothe_id`) REFERENCES `clothe` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
