CREATE DEFINER=`root`@`%` PROCEDURE `REGISTRY_CLEANUP_TASK`()
BEGIN

DECLARE rowCount INT;
DECLARE sleepTime FLOAT;
DECLARE backupTables BOOLEAN;
DECLARE tracingEnabled BOOLEAN;
DECLARE deletedRRP INT;
DECLARE deletedRP INT;
DECLARE deletedRR INT;
DECLARE deletedCount INT;

SET @rowCount = 0;
SET @deletedRRP = 0;
SET @deletedRP = 0;
SET @deletedRR = 0;
SET @deletedCount = 0;
SET backupTables = TRUE;
SET tracingEnabled = TRUE;

SET @OLD_SQL_SAFE_UPDATES = @@SQL_SAFE_UPDATES;
SET SQL_SAFE_UPDATES = 0;

SELECT 'REGISTRY_CLEANUP_TASK STARTED .... !' AS 'INFO LOG';

DROP TABLE IF EXISTS  TEMP_EXPIRED_DATA;
DROP TABLE IF EXISTS  TEMP_DATA_CHUNKS;
DROP TABLE IF EXISTS  TEMP_REG_PROP;


IF (backupTables)
THEN
	SELECT 'BACKING UP TABLES .... !' AS 'INFO LOG';

	DROP TABLE IF EXISTS  REG_RESOURCE_PROPERTY_BCK;
  CREATE TABLE REG_RESOURCE_PROPERTY_BCK SELECT * FROM REG_RESOURCE_PROPERTY;

  SELECT 'BACKED UP  REG_RESOURCE_PROPERTY TABLE. RECORDS FOUND: ' AS 'INFO LOG', COUNT(1) FROM REG_RESOURCE_PROPERTY_BCK;

	DROP TABLE IF EXISTS  REG_PROPERTY_BCK;
  CREATE TABLE REG_PROPERTY_BCK SELECT * FROM REG_PROPERTY;

	SELECT 'BACKED UP  REG_PROPERTY TABLE. RECORDS FOUND: ' AS 'INFO LOG', COUNT(1) FROM REG_PROPERTY_BCK;

  DROP TABLE IF EXISTS  REG_RESOURCE_BCK;
  CREATE TABLE REG_RESOURCE_BCK SELECT * FROM REG_RESOURCE;

	SELECT 'BACKED UP  REG_RESOURCE TABLE. RECORDS FOUND: ' AS 'INFO LOG', COUNT(1) FROM REG_RESOURCE_BCK;

END IF;


CREATE TEMPORARY TABLE IF NOT EXISTS TEMP_EXPIRED_DATA
(INDEX IDX_TEMP_EXPIRED_DATA_REG_VERSION (REG_VERSION))
AS (

	SELECT REG_VERSION
	FROM REG_RESOURCE
			JOIN
		REG_PATH
	WHERE
		REG_RESOURCE.REG_PATH_ID = REG_PATH.REG_PATH_ID
		AND REG_PATH.REG_PATH_VALUE = '/_system/config/repository/components/org.wso2.carbon.identity.mgt/data'
		AND REG_VERSION IN (SELECT
			REG_VERSION
		FROM
			REG_RESOURCE_PROPERTY
				JOIN
			REG_PROPERTY
		WHERE
			REG_RESOURCE_PROPERTY.REG_PROPERTY_ID = REG_PROPERTY.REG_ID
			AND REG_PROPERTY.REG_NAME = 'expireTime'
			AND REG_PROPERTY.REG_VALUE / 1000 < UNIX_TIMESTAMP())
);


SELECT 'START REMOVING EXPIRED CODES. RECORDS FOUND: ' AS 'INFO LOG', COUNT(1) FROM TEMP_EXPIRED_DATA;

REPEAT

IF ((@rowCount > 0))
THEN
    DO SLEEP(sleepTime);
END IF;

CREATE TEMPORARY TABLE IF NOT EXISTS TEMP_DATA_CHUNKS AS (SELECT REG_VERSION FROM TEMP_EXPIRED_DATA LIMIT 5000);

CREATE TEMPORARY TABLE IF NOT EXISTS TEMP_REG_PROP AS (SELECT REG_ID FROM REG_PROPERTY RP, REG_RESOURCE_PROPERTY RRP WHERE RP.REG_ID = RRP.REG_PROPERTY_ID AND RRP.REG_VERSION IN (SELECT REG_VERSION FROM TEMP_DATA_CHUNKS));

DELETE A
FROM REG_RESOURCE_PROPERTY AS A
INNER JOIN TEMP_DATA_CHUNKS AS B
	ON A.REG_VERSION = B.REG_VERSION;

IF (tracingEnabled)
THEN
	SELECT row_count() INTO @deletedCount;
    SET @deletedRRP = @deletedRRP + @deletedCount;
    SET @deletedCount = 0;
END IF;

DELETE A
FROM REG_PROPERTY AS A
INNER JOIN TEMP_REG_PROP AS B
	ON A.REG_ID = B.REG_ID;

IF (tracingEnabled)
THEN
	SELECT row_count() INTO @deletedCount;
    SET @deletedRP = @deletedRP + @deletedCount;
    SET @deletedCount = 0;
END IF;

DELETE A
FROM REG_RESOURCE AS A
INNER JOIN TEMP_DATA_CHUNKS AS B
	ON A.REG_VERSION = B.REG_VERSION;

IF (tracingEnabled)
THEN
	SELECT row_count() INTO @deletedCount;
    SET @deletedRR = @deletedRR + @deletedCount;
    SET @deletedCount = 0;
END IF;

DELETE A
FROM TEMP_EXPIRED_DATA AS A
INNER JOIN TEMP_DATA_CHUNKS AS B
	ON A.REG_VERSION = B.REG_VERSION;

DROP TABLE IF EXISTS  TEMP_DATA_CHUNKS;
DROP TABLE IF EXISTS  TEMP_REG_PROP;

SELECT COUNT(*)  FROM TEMP_EXPIRED_DATA INTO @rowCount;

UNTIL @rowCount = 0 END REPEAT;

IF (tracingEnabled)
THEN
	SELECT 'RECORDS REMOVED FROM REG_RESOURCE_PROPERTY: ' AS 'INFO LOG', @deletedRRP;
	SELECT 'RECORDS REMOVED FROM REG_PROPERTY: ' AS 'INFO LOG', @deletedRP;
	SELECT 'RECORDS REMOVED FROM REG_RESOURCE: ' AS 'INFO LOG', @deletedRR;
END IF;

DROP TABLE IF EXISTS  TEMP_EXPIRED_DATA;

SET SQL_SAFE_UPDATES = @OLD_SQL_SAFE_UPDATES;

SELECT 'REGISTRY_CLEANUP_TASK COMPLETED .... !' AS 'INFO LOG';

END
