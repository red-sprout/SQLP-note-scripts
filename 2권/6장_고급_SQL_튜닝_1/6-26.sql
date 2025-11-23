DROP TABLE IF EXISTS 상태변경이력 CASCADE CONSTRAINTS;
DROP TABLE IF EXISTS 장비 CASCADE CONSTRAINTS;

CREATE TABLE 장비 (
    장비번호 VARCHAR2(10) NOT NULL,
    장비명 VARCHAR2(40) NOT NULL,
    장비구분코드 VARCHAR2(4) NOT NULL,
    CONSTRAINT 장비_PK PRIMARY KEY (장비번호)
);

CREATE TABLE 상태변경이력 (
    장비번호 VARCHAR2(10) NOT NULL,
    변경일자 VARCHAR2(8) NOT NULL,
    변경순번 NUMBER(4) NOT NULL,
    상태코드 VARCHAR2(2) NOT NULL,
    CONSTRAINT 상태변경이력_PK PRIMARY KEY (장비번호, 변경일자, 변경순번)
);

TRUNCATE TABLE 상태변경이력;
TRUNCATE TABLE 장비;

INSERT /*+ APPEND */ INTO 장비
SELECT
    'EQ' || LPAD(LEVEL, 8, '0') AS 장비번호,
    '장비_' || LEVEL AS 장비명,
    CHR(65 + MOD(LEVEL - 1, 26)) || LPAD(MOD(LEVEL - 1, 999) + 1, 3, '0') AS 장비구분코드
FROM DUAL
CONNECT BY LEVEL <= 100000;

COMMIT;

INSERT /*+ APPEND */ INTO 상태변경이력
SELECT
    'EQ' || LPAD(CEIL(LEVEL / 10), 8, '0') AS 장비번호,
    TO_CHAR(DATE '2020-01-01' + MOD(LEVEL - 1, 10) * 180 + TRUNC(DBMS_RANDOM.VALUE(0, 30)), 'YYYYMMDD') AS 변경일자,
    MOD(LEVEL - 1, 10) + 1 AS 변경순번,
    LPAD(TRUNC(DBMS_RANDOM.VALUE(1, 10)), 2, '0') AS 상태코드
FROM DUAL
CONNECT BY LEVEL <= 1000000;

COMMIT;

---------------------------------- TEST-----------------------------------------

SELECT 장비번호, 장비명, 상태코드, 변경일자, 변경순번
FROM (
	SELECT A.장비번호, A.장비명, B.상태코드, B.변경일자, B.변경순번,
	       ROW_NUMBER() OVER (PARTITION BY B.장비번호 ORDER BY B.변경일자 DESC, B.변경순번 DESC) AS RN
	FROM 장비 A, 상태변경이력 B
	WHERE A.장비구분코드 = 'A001'
	AND B.장비번호 = A.장비번호
)
WHERE RN = 1;

/*
--------------------------------------------------------------------------------------------
| Id  | Operation                      | Name      | Rows  | Bytes | Cost (%CPU)| Time     |
--------------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT               |           |    39 |  2496 |   165   (1)| 00:00:01 |
|*  1 |  VIEW                          |           |    39 |  2496 |   165   (1)| 00:00:01 |
|*  2 |   WINDOW SORT PUSHED RANK      |           |    39 |  2145 |   165   (1)| 00:00:01 |
|   3 |    NESTED LOOPS                |           |    39 |  2145 |   164   (0)| 00:00:01 |
|   4 |     NESTED LOOPS               |           |    40 |  2145 |   164   (0)| 00:00:01 |
|*  5 |      TABLE ACCESS FULL         | 장비      |     4 |   116 |   136   (0)| 00:00:01 |
|*  6 |      INDEX RANGE SCAN          | 상태변경이|    10 |       |     2   (0)| 00:00:01 |
|   7 |     TABLE ACCESS BY INDEX ROWID| 상태변경이|    10 |   260 |     7   (0)| 00:00:01 |
--------------------------------------------------------------------------------------------
*/

SELECT 장비번호, 장비명
    , SUBSTR(최종이력, 13) AS 최종상태코드
    , SUBSTR(최종이력, 1, 8) AS 최종변경일자
    , SUBSTR(최종이력, 9, 4) AS 최종변경순번
FROM (
    SELECT 장비번호, 장비명
        , (SELECT 변경일자 || LPAD(변경순번, 4) || 상태코드
           FROM (SELECT 변경일자, 변경순번, 상태코드
                 FROM 상태변경이력
                 WHERE 장비번호 = A.장비번호
                 ORDER BY 변경일자 DESC, 변경순번 DESC)
           WHERE ROWNUM <= 1) 최종이력
    FROM 장비 A
    WHERE 장비구분코드 = 'A001'
     );

/*
--------------------------------------------------------------------------------------------
| Id  | Operation                      | Name      | Rows  | Bytes | Cost (%CPU)| Time     |
--------------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT               |           |     4 |   116 |   148   (1)| 00:00:01 |
|*  1 |  COUNT STOPKEY                 |           |       |       |            |          |
|   2 |   VIEW                         |           |     2 |    44 |     4   (0)| 00:00:01 |
|   3 |    TABLE ACCESS BY INDEX ROWID | 상태변경이|    10 |   260 |     4   (0)| 00:00:01 |
|*  4 |     INDEX RANGE SCAN DESCENDING| 상태변경이|     2 |       |     3   (0)| 00:00:01 |
|*  5 |  TABLE ACCESS FULL             | 장비      |     4 |   116 |   136   (0)| 00:00:01 |
--------------------------------------------------------------------------------------------
*/

SELECT A.장비번호, A.장비명, B.상태코드, B.변경일자, B.변경순번
FROM 장비 A, 상태변경이력 B
WHERE A.장비구분코드 = 'A001'
AND B.장비번호 = A.장비번호
AND (B.변경일자, B.변경순번) = (
	SELECT 변경일자, 변경순번
	FROM (
		SELECT 변경일자, 변경순번
		FROM 상태변경이력
		WHERE 장비번호 = A.장비번호
		ORDER BY 변경일자 DESC, 변경순번 DESC
	)
	WHERE ROWNUM <= 1
);

/*
----------------------------------------------------------------------------------------------
| Id  | Operation                        | Name      | Rows  | Bytes | Cost (%CPU)| Time     |
----------------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT                 |           |     1 |    55 |   144   (0)| 00:00:01 |
|   1 |  NESTED LOOPS                    |           |     1 |    55 |   144   (0)| 00:00:01 |
|   2 |   NESTED LOOPS                   |           |     4 |    55 |   144   (0)| 00:00:01 |
|*  3 |    TABLE ACCESS FULL             | 장비      |     4 |   116 |   136   (0)| 00:00:01 |
|*  4 |    INDEX UNIQUE SCAN             | 상태변경이|     1 |       |     1   (0)| 00:00:01 |
|*  5 |     COUNT STOPKEY                |           |       |       |            |          |
|   6 |      VIEW                        |           |     2 |    38 |     3   (0)| 00:00:01 |
|*  7 |       INDEX RANGE SCAN DESCENDING| 상태변경이|    10 |   230 |     3   (0)| 00:00:01 |
|   8 |   TABLE ACCESS BY INDEX ROWID    | 상태변경이|     1 |    26 |     2   (0)| 00:00:01 |
----------------------------------------------------------------------------------------------
*/
