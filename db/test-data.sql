START TRANSACTION;

INSERT
  INTO `user` ( `id`, `name`, `email`, `password`, `create_date` )
  VALUES
    ( 2, '한만일', '10001if@opencloset.net',   NULL, NOW() ),
    ( 3, '김소령', 'commander@opencloset.net', NULL, NOW() ),
    ( 4, '홍형석', 'aanoaa@gmail.com',         NULL, NOW() )
    ;

-- INSERT
--   INTO `user_info` ( `id`, `user_id`, `phone`, `address`, `gender`, `birth` )
--   VALUES
--     ( 1, 1, '01012345678', '인천 송도',   'male',   1980 ),
--     ( 2, 2, '01024681357', '서울 신사동', 'female', 1979 ),
--     ( 3, 3, '01011112222', '서울 사당동', 'male',   1982 )
--     ;

--
-- 기증자
--
INSERT
  INTO `user_info` ( `id`, `user_id`, `phone`, `address`, `gender`, `birth`, `comment` )
  VALUES
    ( 1, 2, '01012345678', '인천 송도',   'male',   1980, '열린옷장대표1' ),
    ( 2, 3, '01024681357', '서울 신사동', 'female', 1979, '열린옷장대표2' )
    ;

--
-- 대여자
--
INSERT
  INTO `user_info` (
    `id`, `user_id`, `phone`, `address`, `gender`, `birth`, `comment`,
    `height`, `weight`, `bust`, `waist`, `hip`, `thigh`, `arm`, `leg`, `knee`, `foot`
  )
  VALUES
    ( 3, 4, '01011112222', '서울 사당동', 'male', 1982, '최초 대여자', 168, 59, 93, 78, NULL, NULL, 51, 102, NULL, NULL )
    ;

INSERT
  INTO `clothes` (
    `id`,`code`,`bust`,`waist`,`arm`,`length`,`category`,
    `user_id`,`status_id`,`gender`,`color`,`compatible_code`
  )
  VALUES 
    (1,'0J001', 94, NULL, 51, NULL,     'jacket', 2, 1, 1,'B',NULL),
    (2,'0P001', NULL, 79, NULL, 102,    'pants',  2, 1, 1,'B',NULL),
    (3,'0S001', NULL, NULL, NULL, NULL, 'shirt',  2, 1, 1,'B',NULL),
    (4,'0A001', NULL, NULL, NULL, NULL, 'shoes',  2, 1, 1,'B',NULL),
    (5,'0T001', NULL, NULL, NULL, NULL, 'tie',    2, 1, 1,'B',NULL)
    ;

INSERT
  INTO `donor_clothes` (`user_id`, `clothes_id`, `comment`, `donation_date`)
  VALUES (2, 1, '필요없어서 했습니다', NOW()), (2, 2, '', NOW());

-- 대여중인거
INSERT
  INTO `clothes` (`id`,`code`,`bust`,`waist`,`arm`,`length`,`category`,`user_id`,`status_id`)
  VALUES
    (6,'0J002', 99, NULL, 55, NULL, 'jacket', 2, 2),
    (7,'0P002', NULL, 82, NULL, 112, 'pants', 2, 2)
    ;

INSERT
  INTO `donor_clothes` (`user_id`, `clothes_id`, `comment`, `donation_date`)
  VALUES (2, 3, '남아서..', NOW()), (1, 4, '', NOW())
  ;

INSERT
  INTO `order` (
    `id`,`user_id`,`status_id`,`rental_date`,`target_date`,`return_date`,
    `price`,`discount`,`comment`,`payment_method`,`staff_name`,`purpose`,`bust`,`waist`,`arm`,`leg`
  )
  VALUES
    (1,2,2,'2013-10-18','2013-10-21',NULL,20000,0,NULL,'현금','김소령','입사면접',95,78,60,105);

INSERT INTO `order_clothes` (`order_id`, `clothes_id`) VALUES (1,6), (1,7);

INSERT
  INTO `satisfaction` (`user_id`,`clothes_id`,`bust`,`waist`,`arm`,`top_fit`,`bottom_fit`,`create_date`)
  VALUES (2,6,1,2,3,4,5,'2013-10-18')
  ;

COMMIT;
