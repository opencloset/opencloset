START TRANSACTION;
INSERT INTO `donor` (`id`, `name`) VALUES (1, '한만일'),(2, '김소령');
INSERT INTO `clothes` (`id`,`no`,`chest`,`waist`,`arm`,`pants_len`,`category_id`,`top_id`,`bottom_id`,`donor_id`,`status_id`) VALUES (1,'J00001', 94, 78, 51, NULL, 1, NULL, NULL, 1, 1), (2,'P00001', NULL, NULL, NULL, 102, 2, NULL, NULL, 1, 1);
UPDATE `clothes` SET `bottom_id`=2 WHERE `id`=1;
UPDATE `clothes` SET `top_id`=1 WHERE `id`=2;
INSERT INTO `donor_clothes` (`donor_id`, `clothes_id`, `comment`, `donation_date`) VALUES (1, 1, '필요없어서 했습니다', NOW()), (1, 2, '', NOW());
COMMIT;
