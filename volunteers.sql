CREATE TABLE `volunteer` (
  `id`                 INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `name`               VARCHAR(32)  NOT NULL,
  `email`              VARCHAR(128) DEFAULT NULL,
  `birth_date`         DATETIME     DEFAULT NULL,
  `phone`              VARCHAR(16)  DEFAULT NULL COMMENT 'regex: 01\d{8,9}',
  `address`            TEXT         DEFAULT NULL,
  `activity_date`      DATETIME     NOT NULL,
  `activity_hour_from` INT          DEFAULT NULL,
  `activity_hour_to`   INT          DEFAULT NULL,
  `reason`             TEXT         DEFAULT NULL,
  `path`               TEXT         DEFAULT NULL,
  `period`             VARCHAR(32)  DEFAULT NULL,
  `activity`           TEXT         DEFAULT NULL,
  `comment`            TEXT         DEFAULT NULL,

  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
