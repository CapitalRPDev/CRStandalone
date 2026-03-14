CREATE TABLE IF NOT EXISTS `police_officers` (
    `id`         INT(11)      NOT NULL AUTO_INCREMENT,
    `citizenid`  VARCHAR(50)  NOT NULL,
    `name`       VARCHAR(100) NOT NULL,
    `callsign`   VARCHAR(20)  NOT NULL,
    `division`   VARCHAR(50)  NOT NULL,
    `grade`      VARCHAR(50)  NOT NULL DEFAULT 'Constable',
    `password`   VARCHAR(255) NOT NULL,
    `on_duty`    TINYINT(1)   NOT NULL DEFAULT 0,
    `hired_by`   VARCHAR(50)  DEFAULT NULL,
    `hired_at`   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `unique_citizenid` (`citizenid`)
);


INSERT INTO `police_officers` (`citizenid`, `name`, `callsign`, `division`, `grade`, `password`, `on_duty`, `hired_by`)
VALUES ('R2HZ5Y4S', 'Marius Hanssen', '2043T', 'Armed Response', 'Sergeant', 'admin', 0, NULL);




CREATE TABLE IF NOT EXISTS `police_evidence` (
    `id`            INT(11)      NOT NULL AUTO_INCREMENT,
    `code`          VARCHAR(20)  NOT NULL,
    `cad_reference` VARCHAR(50)  NOT NULL,
    `callsign`      VARCHAR(20)  NOT NULL,
    `material`      VARCHAR(255) NOT NULL,
    `pack_id`       VARCHAR(50)  NOT NULL,
    `comment`       TEXT         DEFAULT NULL,
    `logged_by`     VARCHAR(50)  NOT NULL,
    `logged_at`     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `unique_code` (`code`)
);