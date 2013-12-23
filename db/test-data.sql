START TRANSACTION;

INSERT
  INTO `user` ( `id`, `name`, `email`, `password`, `create_date`, `update_date` )
  VALUES
    ( 2, '한만일', '10001if@opencloset.net',   NULL, NOW(), NOW() ),
    ( 3, '김소령', 'commander@opencloset.net', NULL, NOW(), NOW() ),
    ( 4, '홍형석', 'aanoaa@gmail.com',         NULL, NOW(), NOW() )
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
    ( 2, 2, '01012345678', '인천 송도',   'male',   1980, '열린옷장대표1' ),
    ( 3, 3, '01024681357', '서울 신사동', 'female', 1979, '열린옷장대표2' )
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
    ( 4, 4, '01011112222', '서울 사당동', 'male', 1982, '최초 대여자', 168, 59, 93, 78, NULL, NULL, 51, 102, NULL, NULL )
    ;

INSERT
  INTO `clothes` (
    `id`,`code`,`bust`,`waist`,`arm`,`length`,`category`,`price`,
    `user_id`,`status_id`,`gender`,`color`,`compatible_code`
  )
  VALUES 
    (1, '0J001', 94,   NULL, 51,   NULL, 'jacket', 15000, 2, 1, 'male', 'B', NULL),
    (2, '0P001', NULL, 79,   NULL, 102,  'pants',  10000, 2, 1, 'male', 'B', NULL),
    (3, '0S001', NULL, NULL, NULL, NULL, 'shirt',   5000, 2, 1, 'male', 'B', NULL),
    (4, '0A001', NULL, NULL, NULL, NULL, 'shoes',   5000, 2, 1, 'male', 'B', NULL),
    (5, '0T001', NULL, NULL, NULL, NULL, 'tie',     5000, 2, 1, 'male', 'B', NULL)
    ;

INSERT
  INTO `donor_clothes` (`user_id`, `clothes_code`, `comment`, `donation_date`)
  VALUES
    (2, '0J001', '필요없어서 했습니다', NOW()),
    (2, '0P001', '',                    NOW())
    ;

-- 대여중인거
INSERT
  INTO `clothes` (`id`,`code`,`bust`,`waist`,`arm`,`length`,`category`,`price`,`user_id`,`status_id`)
  VALUES
    (6,'0J002', 99, NULL, 55, NULL, 'jacket', '15000', 2, 2),
    (7,'0P002', NULL, 82, NULL, 112, 'pants', '10000', 2, 2)
    ;

INSERT
  INTO `donor_clothes` (`user_id`, `clothes_code`, `comment`, `donation_date`)
  VALUES
    (2, '0S001', '남아서..', NOW()),
    (1, '0A001', '',         NOW())
    ;

INSERT
  INTO `order` (
    `id`,`user_id`,`status_id`,`rental_date`,`target_date`,`return_date`,
    `desc`,`payment_method`,`staff_name`,`purpose`,`bust`,`waist`,`arm`,`leg`
  )
  VALUES
    (1,2,2,'2013-10-18','2013-10-21',NULL,NULL,'현금','김소령','입사면접',95,78,60,105);

INSERT INTO `order_clothes` (`order_id`, `clothes_code`) VALUES (1,'0J002'), (1,'0P002');

INSERT
  INTO `order_detail` (`order_id`, `clothes_code`, `name`, `price`, `desc`)
  VALUES
    (1, '0J002', 'J002 - jacket', 15000, '2번 기증 재킷'),
    (1, '0P002', 'P002 - pants',  10000, '2번 기증 바지'),
    (1, NULL,    '에누리',        -2500, '대여자 상황을 고려해 택배비 에누리')
  ;

INSERT
  INTO `satisfaction` (`user_id`,`clothes_code`,`bust`,`waist`,`arm`,`top_fit`,`bottom_fit`,`create_date`)
  VALUES (2,'0J002',1,2,3,4,5,'2013-10-18')
  ;

COMMIT;
