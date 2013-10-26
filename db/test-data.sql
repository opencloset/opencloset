START TRANSACTION;
INSERT INTO `donor` (`id`, `name`) VALUES (1, '한만일'),(2, '김소령');
INSERT INTO `clothe` (`id`,`no`,`chest`,`waist`,`arm`,`pants_len`,`category_id`,`top_id`,`bottom_id`,`donor_id`,`status_id`) VALUES (1,'J00001', 94, 78, 51, NULL, 1, NULL, NULL, 1, 1), (2,'P00001', NULL, NULL, NULL, 102, 2, NULL, NULL, 1, 1);
UPDATE `clothe` SET `bottom_id`=2 WHERE `id`=1;
UPDATE `clothe` SET `top_id`=1 WHERE `id`=2;
INSERT INTO `donor_clothe` (`donor_id`, `clothe_id`, `comment`, `donation_date`) VALUES (1, 1, '필요없어서 했습니다', NOW()), (1, 2, '', NOW());

-- 대여중인거
INSERT INTO `clothe` (`id`,`no`,`chest`,`waist`,`arm`,`pants_len`,`category_id`,`top_id`,`bottom_id`,`donor_id`,`status_id`) VALUES (3,'J00002', 99, 82, 55, NULL, 1, NULL, NULL, 1, 2), (4,'P00002', NULL, NULL, NULL, 112, 2, NULL, NULL, 1, 2);
UPDATE `clothe` SET `bottom_id`=4 WHERE `id`=3;
UPDATE `clothe` SET `top_id`=3 WHERE `id`=4;
INSERT INTO `donor_clothe` (`donor_id`, `clothe_id`, `comment`, `donation_date`) VALUES (1, 3, '남아서..', NOW()), (1, 4, '', NOW());

INSERT INTO `guest` (`id`,`name`,`email`,`phone`,`gender`,`address`,`age`,`purpose`,`chest`,`waist`,`arm`,`pants_len`,`height`,`weight`,`create_date`,`visit_date`) VALUES (1,'홍형석','aanoaa@gmail.com','01031820000',0,'서울시 동작구 사당동',32,'입사면접',93,78,51,102,168,59,'2013-01-03','2013-01-03');

INSERT INTO `order` (`id`,`guest_id`,`status_id`,`rental_date`,`target_date`,`return_date`,`price`,`discount`,`comment`) VALUES (1,1,2,'2013-10-18','2013-10-21',NULL,20000,0,NULL);

INSERT INTO `clothe_order` (`clothe_id`,`order_id`) VALUES (3,1), (4,1);

INSERT INTO `satisfaction` (`guest_id`,`clothe_id`,`chest`,`waist`,`arm`,`top_fit`,`bottom_fit`,`create_date`) VALUES (1,3,1,2,3,4,5,'2013-10-18');
COMMIT;
