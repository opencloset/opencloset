START TRANSACTION;

INSERT
  INTO `user` ( `id`, `name`, `email`, `password`, `create_date` )
  VALUES
    ( 1, '한만일', '10001if@opencloset.net',   NULL, NOW() ),
    ( 2, '김소령', 'commander@opencloset.net', NULL, NOW() ),
    ( 3, '홍형석', 'aanoaa@gmail.com',         NULL, NOW() )
    ;

-- INSERT
--   INTO `userinfo` ( `id`, `user_id`, `phone`, `address`, `gender`, `birth` )
--   VALUES
--     ( 1, 1, '01012345678', '인천 송도',   'male',   1980 ),
--     ( 2, 2, '01024681357', '서울 신사동', 'female', 1979 ),
--     ( 3, 3, '01011112222', '서울 사당동', 'male',   1982 )
--     ;

--
-- 기증자
--
INSERT
  INTO `userinfo` ( `id`, `user_id`, `phone`, `address`, `gender`, `birth`, `comment` )
  VALUES
    ( 1, 1, '01012345678', '인천 송도',   'male',   1980, '열린옷장대표1' ),
    ( 2, 2, '01024681357', '서울 신사동', 'female', 1979, '열린옷장대표2' )
    ;

--
-- 대여자
--
INSERT
  INTO `userinfo` (
    `id`, `user_id`, `phone`, `address`, `gender`, `birth`, `comment`,
    `height`, `weight`, `bust`, `waist`, `hip`, `thigh`, `arm`, `leg`, `knee`, `foot`
  )
  VALUES
    ( 3, 3, '01011112222', '서울 사당동', 'male', 1982, '최초 대여자', 168, 59, 93, 78, NULL, NULL, 51, 102, NULL, NULL )
    ;

INSERT
  INTO `cloth` (
    `id`,`code`,`bust`,`waist`,`arm`,`length`,`category`,
    `top_id`,`bottom_id`,`user_id`,`status_id`,`gender`,`color`,`compatible_code`
  )
  VALUES 
    (1,'0J001', 94, NULL, 51, NULL,     'jacket', NULL, NULL, 1, 1, 1,'B',NULL),
    (2,'0P001', NULL, 79, NULL, 102,    'pants',  NULL, NULL, 1, 1, 1,'B',NULL),
    (3,'0S001', NULL, NULL, NULL, NULL, 'shirt',  NULL, NULL, 1, 1, 1,'B',NULL),
    (4,'0A001', NULL, NULL, NULL, NULL, 'shoes',  NULL, NULL, 1, 1, 1,'B',NULL),
    (5,'0T001', NULL, NULL, NULL, NULL, 'tie',    NULL, NULL, 1, 1, 1,'B',NULL)
    ;
UPDATE `cloth` SET `bottom_id`=2 WHERE `id`=1;
UPDATE `cloth` SET `top_id`=1 WHERE `id`=2;

INSERT
  INTO `donor_cloth` (`user_id`, `cloth_id`, `comment`, `donation_date`)
  VALUES (1, 1, '필요없어서 했습니다', NOW()), (1, 2, '', NOW());

-- 대여중인거
INSERT
  INTO `cloth` (`id`,`code`,`bust`,`waist`,`arm`,`length`,`category`,`top_id`,`bottom_id`,`user_id`,`status_id`)
  VALUES
    (6,'0J002', 99, NULL, 55, NULL, 'jacket', NULL, NULL, 1, 2),
    (7,'0P002', NULL, 82, NULL, 112, 'pants', NULL, NULL, 1, 2)
    ;
UPDATE `cloth` SET `bottom_id`=7 WHERE `id`=6;
UPDATE `cloth` SET `top_id`=6 WHERE `id`=7;

INSERT
  INTO `donor_cloth` (`user_id`, `cloth_id`, `comment`, `donation_date`)
  VALUES (1, 3, '남아서..', NOW()), (1, 4, '', NOW())
  ;

INSERT
  INTO `order` (
    `id`,`user_id`,`status_id`,`rental_date`,`target_date`,`return_date`,
    `price`,`discount`,`comment`,`payment_method`,`staff_name`,`purpose`,`bust`,`waist`,`arm`,`length`
  )
  VALUES
    (1,1,2,'2013-10-18','2013-10-21',NULL,20000,0,NULL,'현금','김소령','입사면접',95,78,60,105);

INSERT INTO `cloth_order` (`cloth_id`,`order_id`) VALUES (6,1), (7,1);

INSERT
  INTO `satisfaction` (`user_id`,`cloth_id`,`bust`,`waist`,`arm`,`top_fit`,`bottom_fit`,`create_date`)
  VALUES (1,6,1,2,3,4,5,'2013-10-18')
  ;

COMMIT;
