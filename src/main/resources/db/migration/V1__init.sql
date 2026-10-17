
CREATE TABLE `author` (
  `dob` datetime(6) DEFAULT NULL,
  `id` bigint NOT NULL AUTO_INCREMENT,
  `name` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `book` (
  `genre` tinyint DEFAULT NULL,
  `author_id` bigint DEFAULT NULL,
  `book_id` bigint NOT NULL AUTO_INCREMENT,
  `publication_date` datetime(6) DEFAULT NULL,
  `isbn` varchar(255) DEFAULT NULL,
  `title` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`book_id`),
  KEY `FKklnrv3weler2ftkweewlky958` (`author_id`),
  CONSTRAINT `FKklnrv3weler2ftkweewlky958` FOREIGN KEY (`author_id`) REFERENCES `author` (`id`),
  CONSTRAINT `book_chk_1` CHECK ((`genre` between 0 and 4))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `patron` (
  `patronid` bigint NOT NULL AUTO_INCREMENT,
  `registration_date` datetime(6) DEFAULT NULL,
  `email` varchar(255) DEFAULT NULL,
  `name` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`patronid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `lending` (
  `lending_status` tinyint DEFAULT NULL,
  `book_book_id` bigint DEFAULT NULL,
  `date_borrowed` datetime(6) DEFAULT NULL,
  `date_returned` datetime(6) DEFAULT NULL,
  `due_date` datetime(6) DEFAULT NULL,
  `lendingid` bigint NOT NULL AUTO_INCREMENT,
  `patron_patronid` bigint DEFAULT NULL,
  PRIMARY KEY (`lendingid`),
  KEY `FK7wv2c6en8rvepjia7apjphh3a` (`book_book_id`),
  KEY `FK4x4n3oth5wgugum4p2cu0c98x` (`patron_patronid`),
  CONSTRAINT `FK4x4n3oth5wgugum4p2cu0c98x` FOREIGN KEY (`patron_patronid`) REFERENCES `patron` (`patronid`),
  CONSTRAINT `FK7wv2c6en8rvepjia7apjphh3a` FOREIGN KEY (`book_book_id`) REFERENCES `book` (`book_id`),
  CONSTRAINT `lending_chk_1` CHECK ((`lending_status` between 0 and 1))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;



