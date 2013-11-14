START TRANSACTION;

INSERT INTO `user`
  (`id`,`name`,`email`,`phone`,`gender`,`age`,`address`,`create_date`)
VALUES
  (1,'한만일','10001if@opencloset.net','01000000000',1,33,'인천 송도',NOW()),
  (2,'김소령','commander@opencloset.net','01000000001',2,33,'서울 신사동',NOW()),
  (3,'홍형석','aanoaa@gmail.com','01000000002',1,32,'서울 사당동',NOW());

INSERT INTO `donor`
  (`id`,`user_id`,`donation_msg`,`comment`,`create_date`)
VALUES
  (1,1,'잘입으셈','열린옷장대표1',NOW()),
  (2,2,'후후후후','열린옷장대표2',NOW());

INSERT INTO `cloth` (`id`,`no`,`chest`,`waist`,`arm`,`length`,`category_id`,`top_id`,`bottom_id`,`donor_id`,`status_id`,`gender`,`color`,`compatible_code`) VALUES 
(1,'JCK00001', 94, NULL, 51, NULL, 1, NULL, NULL, 1, 1, 1,'B',NULL),
(2,'PTS00001', NULL, 79, NULL, 102, 2, NULL, NULL, 1, 1, 1,'B',NULL),
(3,'SHR00001', NULL, NULL, NULL, NULL, 3, NULL, NULL, 1, 1, 1,'B',NULL),
(4,'SHO00001', NULL, NULL, NULL, NULL, 4, NULL, NULL, 1, 1, 1,'B',NULL),
(5,'TIE00001', NULL, NULL, NULL, NULL, 6, NULL, NULL, 1, 1, 1,'B',NULL);
UPDATE `cloth` SET `bottom_id`=2 WHERE `id`=1;
UPDATE `cloth` SET `top_id`=1 WHERE `id`=2;
INSERT INTO `donor_cloth` (`donor_id`, `cloth_id`, `comment`, `donation_date`) VALUES (1, 1, '필요없어서 했습니다', NOW()), (1, 2, '', NOW());

-- 대여중인거
INSERT INTO `cloth` (`id`,`no`,`chest`,`waist`,`arm`,`length`,`category_id`,`top_id`,`bottom_id`,`donor_id`,`status_id`) VALUES (6,'JCK00002', 99, NULL, 55, NULL, 1, NULL, NULL, 1, 2), (7,'PTS00002', NULL, 82, NULL, 112, 2, NULL, NULL, 1, 2);
UPDATE `cloth` SET `bottom_id`=7 WHERE `id`=6;
UPDATE `cloth` SET `top_id`=6 WHERE `id`=7;
INSERT INTO `donor_cloth` (`donor_id`, `cloth_id`, `comment`, `donation_date`) VALUES (1, 3, '남아서..', NOW()), (1, 4, '', NOW());

INSERT INTO `guest`
  (`id`,`user_id`,`chest`,`waist`,`arm`,`length`,`height`,`weight`,`purpose`,`domain`,`create_date`,`visit_date`,`target_date`)
VALUES
  (1,3,93,78,51,102,168,59,'입사면접','software',NOW(),NOW(),DATE_ADD(NOW(), INTERVAL 3 day));

INSERT INTO `order` (`id`,`guest_id`,`status_id`,`rental_date`,`target_date`,`return_date`,`price`,`discount`,`comment`,`payment_method`,`staff_name`,`purpose`,`chest`,`waist`,`arm`,`length`) VALUES (1,1,2,'2013-10-18','2013-10-21',NULL,20000,0,NULL,'현금','김소령','입사면접',95,78,60,105);

INSERT INTO `cloth_order` (`cloth_id`,`order_id`) VALUES (6,1), (7,1);

INSERT INTO `satisfaction` (`guest_id`,`cloth_id`,`chest`,`waist`,`arm`,`top_fit`,`bottom_fit`,`create_date`) VALUES (1,6,1,2,3,4,5,'2013-10-18');
COMMIT;
