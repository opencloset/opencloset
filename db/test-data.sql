START TRANSACTION;
INSERT INTO `donor` (`id`, `name`,`email`,`phone`,`comment`,`gender`,`address`,`message`) VALUES (1,'한만일','10001if@opencloset.net','01011118282',NULL,0,'인천','안녕~'),(2,'김소령','commander@opencloset.net','01000001111',NULL,1,'서울 신사동','(*-*)b');
INSERT INTO `clothe` (`id`,`no`,`chest`,`waist`,`arm`,`length`,`category_id`,`top_id`,`bottom_id`,`donor_id`,`status_id`) VALUES 
(1,'Jck00001', 94, NULL, 51, NULL, 1, NULL, NULL, 1, 1),
(2,'Pts00001', NULL, 79, NULL, 102, 2, NULL, NULL, 1, 1),
(3,'Shr00001', NULL, NULL, NULL, NULL, 3, NULL, NULL, 1, 1),
(4,'Sho00001', NULL, NULL, NULL, NULL, 4, NULL, NULL, 1, 1),
(5,'Tie00001', NULL, NULL, NULL, NULL, 6, NULL, NULL, 1, 1);
UPDATE `clothe` SET `bottom_id`=2 WHERE `id`=1;
UPDATE `clothe` SET `top_id`=1 WHERE `id`=2;
INSERT INTO `donor_clothe` (`donor_id`, `clothe_id`, `comment`, `donation_date`) VALUES (1, 1, '필요없어서 했습니다', NOW()), (1, 2, '', NOW());

-- 대여중인거
INSERT INTO `clothe` (`id`,`no`,`chest`,`waist`,`arm`,`length`,`category_id`,`top_id`,`bottom_id`,`donor_id`,`status_id`) VALUES (6,'Jck00002', 99, NULL, 55, NULL, 1, NULL, NULL, 1, 2), (7,'Pts00002', NULL, 82, NULL, 112, 2, NULL, NULL, 1, 2);
UPDATE `clothe` SET `bottom_id`=7 WHERE `id`=6;
UPDATE `clothe` SET `top_id`=6 WHERE `id`=7;
INSERT INTO `donor_clothe` (`donor_id`, `clothe_id`, `comment`, `donation_date`) VALUES (1, 3, '남아서..', NOW()), (1, 4, '', NOW());

INSERT INTO `guest` (`id`,`name`,`email`,`phone`,`gender`,`address`,`age`,`purpose`,`chest`,`waist`,`arm`,`length`,`height`,`weight`,`create_date`,`visit_date`) VALUES (1,'홍형석','aanoaa@gmail.com','01031820000',0,'서울시 동작구 사당동',32,'입사면접',93,78,51,102,168,59,'2013-01-03','2013-01-03');

INSERT INTO `order` (`id`,`guest_id`,`status_id`,`rental_date`,`target_date`,`return_date`,`price`,`discount`,`comment`,`payment_method`,`staff_name`) VALUES (1,1,2,'2013-10-18','2013-10-21',NULL,20000,0,NULL,'현금','김소령');

INSERT INTO `clothe_order` (`clothe_id`,`order_id`) VALUES (6,1), (7,1);

INSERT INTO `satisfaction` (`guest_id`,`clothe_id`,`chest`,`waist`,`arm`,`top_fit`,`bottom_fit`,`create_date`) VALUES (1,6,1,2,3,4,5,'2013-10-18');
COMMIT;
