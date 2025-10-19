-- 기존 정보 삭제
DROP TABLE IF EXISTS 주문상태 CASCADE CONSTRAINTS;
DROP TABLE IF EXISTS 주문 CASCADE CONSTRAINTS;

-- DDL
CREATE TABLE 주문 (
                    주문번호 NUMBER,
                    주문일시 TIMESTAMP,
                    주문일자 DATE,
                    고객ID VARCHAR2(20),
                    총주문금액 NUMBER,
                    처리상태 VARCHAR2(20),
                    주문상태코드 NUMBER,
                    PRIMARY KEY (주문번호)
);

CREATE TABLE 주문상태 (
                    주문상태코드 NUMBER,
                    주문상태명 VARCHAR2(20),
                    PRIMARY KEY (주문상태코드)
);

CREATE INDEX idx_주문상태코드_일자 ON 주문(주문상태코드, 주문일자);

-- DML: 샘플 데이터 삽입
-- 주문상태별 데이터 비중: 배송완료(99.93%), 기타(0.07%)

-- 1. 배송완료 데이터 (99.93% = 약 9,993건)
BEGIN
    FOR i IN 1..9993 LOOP
            DECLARE
                v_datetime TIMESTAMP;
                v_date DATE;
            BEGIN
                v_datetime := SYSTIMESTAMP - DBMS_RANDOM.VALUE(1, 365);
                v_date := TRUNC(v_datetime);

                INSERT INTO 주문 VALUES (
                                          i,
                                          v_datetime,
                                          v_date,
                                          'CUST' || LPAD(DBMS_RANDOM.VALUE(1, 1000), 4, '0'),
                                          ROUND(DBMS_RANDOM.VALUE(10000, 500000), -2),
                                          '배송완료',
                                          3
                                      );
            END;
        END LOOP;
    COMMIT;
END;
/

-- 2. 입금확인중 데이터 (0.01% = 약 1건)
INSERT INTO 주문 VALUES (
                          10001,
                          SYSTIMESTAMP - 300,
                          TRUNC(SYSDATE - 1),
                          'CUST0001',
                          150000,
                          '입금확인중',
                          0
                      );

-- 3. 제품준비중 데이터 (0.02% = 약 2건)
INSERT INTO 주문 VALUES (
                          10002,
                          SYSTIMESTAMP - 200,
                          TRUNC(SYSDATE - 2),
                          'CUST0002',
                          200000,
                          '제품준비중',
                          1
                      );

INSERT INTO 주문 VALUES (
                          10003,
                          SYSTIMESTAMP - 50,
                          TRUNC(SYSDATE - 1),
                          'CUST0003',
                          180000,
                          '제품준비중',
                          1
                      );

-- 4. 배송중 데이터 (0.02% = 약 2건)
INSERT INTO 주문 VALUES (
                          10004,
                          SYSTIMESTAMP - 300,
                          TRUNC(SYSDATE - 3),
                          'CUST0004',
                          250000,
                          '배송중',
                          2
                      );

INSERT INTO 주문 VALUES (
                          10005,
                          SYSTIMESTAMP - 200,
                          TRUNC(SYSDATE - 2),
                          'CUST0005',
                          320000,
                          '배송중',
                          2
                      );

-- 5. 재고부족 데이터 (0.01% = 약 1건)
INSERT INTO 주문 VALUES (
                          10006,
                          SYSTIMESTAMP - 100,
                          TRUNC(SYSDATE - 1),
                          'CUST0006',
                          100000,
                          '재고부족',
                          4
                      );

-- 6. 주문취소 데이터 (0.01% = 약 1건)
INSERT INTO 주문 VALUES (
                          10007,
                          SYSTIMESTAMP - 5,
                          TRUNC(SYSDATE - 5),
                          'CUST0007',
                          90000,
                          '주문취소',
                          5
                      );

INSERT INTO 주문상태 VALUES (0, '입금확인중');
INSERT INTO 주문상태 VALUES (1, '제품준비중');
INSERT INTO 주문상태 VALUES (2, '배송중');
INSERT INTO 주문상태 VALUES (3, '배송완료');
INSERT INTO 주문상태 VALUES (4, '재고부족');
INSERT INTO 주문상태 VALUES (5, '주문취소');

SELECT * FROM 주문;

-- 통계 정보 갱신
CALL DBMS_STATS.GATHER_TABLE_STATS('DOCKER', '주문');

-- 실행 계획 확인 (바인드 변수 대신 실제 값 사용)
EXPLAIN PLAN FOR
SELECT 주문번호, 주문일시, 고객ID, 총주문금액, 처리상태
FROM 주문
WHERE 주문상태코드 <> 3
  AND 주문일자 BETWEEN TO_DATE('2025-07-01', 'YYYY-MM-DD')
    AND TO_DATE('2025-12-31', 'YYYY-MM-DD');

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);

-- 데이터 확인
SELECT 주문상태코드, 처리상태, COUNT(*) AS 건수,
       ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS 비율
FROM 주문
GROUP BY 주문상태코드, 처리상태
ORDER BY 주문상태코드;

-------------------------------------------------

SELECT 주문번호, 주문일시, 고객ID, 총주문금액, 처리상태
FROM 주문
WHERE 주문상태코드 <> 3
  AND 주문일자 BETWEEN TO_DATE('2025-07-01', 'YYYY-MM-DD')
    AND TO_DATE('2025-12-31', 'YYYY-MM-DD');

SELECT 주문번호, 주문일시, 고객ID, 총주문금액, 처리상태
FROM 주문
WHERE 주문상태코드 IN (0, 1, 2, 4, 5)
  AND 주문일자 BETWEEN TO_DATE('2025-07-01', 'YYYY-MM-DD')
    AND TO_DATE('2025-12-31', 'YYYY-MM-DD');

SELECT /*+ UNNEST(@SUBQ) LEADING(주문상태@SUBQ) USE_NL(주문) */
    주문번호, 주문일시, 고객ID, 총주문금액, 처리상태
FROM 주문
WHERE 주문상태코드 IN (SELECT /*+ QB_NAME(SUBQ) */ 주문상태코드
                 FROM 주문
                 WHERE 주문상태코드 <> 3)
  AND 주문일자 BETWEEN TO_DATE('2025-07-01', 'YYYY-MM-DD')
    AND TO_DATE('2025-12-31', 'YYYY-MM-DD');

SELECT /*+ ORDERED USE_NL(B) */
    주문번호, 주문일시, 고객ID, 총주문금액, 처리상태
FROM (SELECT 주문상태코드
      FROM 주문
      WHERE 주문상태코드 <> 3)A, 주문 B
WHERE B.주문상태코드 = A.주문상태코드
  AND B.주문일자 BETWEEN TO_DATE('2025-07-01', 'YYYY-MM-DD')
    AND TO_DATE('2025-12-31', 'YYYY-MM-DD');

SELECT /*+ USE_CONCAT */
    주문번호, 주문일시, 고객ID, 총주문금액, 처리상태
FROM 주문
WHERE 주문상태코드 < 3 OR 주문상태코드 > 3
  AND 주문일자 BETWEEN TO_DATE('2025-07-01', 'YYYY-MM-DD')
    AND TO_DATE('2025-12-31', 'YYYY-MM-DD');

SELECT 주문번호, 주문일시, 고객ID, 총주문금액, 처리상태
FROM 주문
WHERE 주문상태코드 < 3
  AND 주문일자 BETWEEN TO_DATE('2025-07-01', 'YYYY-MM-DD')
    AND TO_DATE('2025-12-31', 'YYYY-MM-DD')
UNION ALL
SELECT 주문번호, 주문일시, 고객ID, 총주문금액, 처리상태
FROM 주문
WHERE 주문상태코드 > 3
  AND 주문일자 BETWEEN TO_DATE('2025-07-01', 'YYYY-MM-DD')
    AND TO_DATE('2025-12-31', 'YYYY-MM-DD');