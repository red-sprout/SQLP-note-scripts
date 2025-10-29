DROP TABLE IF EXISTS 고객;
DROP TABLE IF EXISTS 거래;

CREATE TABLE 고객 (
                    고객번호 VARCHAR2(20),
                    고객명 VARCHAR2(20),
                    가입일시 TIMESTAMP,
                    CONSTRAINT 고객_PK PRIMARY KEY (고객번호)
);

CREATE TABLE 거래 (
                    거래번호 VARCHAR2(20),
                    고객번호 VARCHAR2(20),
                    거래일시 TIMESTAMP,
                    거래금액 NUMBER,
                    CONSTRAINT 거래_PK PRIMARY KEY (거래번호)
);

CREATE INDEX 거래_X1 ON 거래(거래일시);

TRUNCATE TABLE 고객;
TRUNCATE TABLE 거래;
-- 1000명의 고객과 100만건의 거래 데이터 생성
DECLARE
    v_start_date DATE := SYSDATE - 1000;
    v_end_date DATE := SYSDATE;
    v_customer_count NUMBER := 1000;
    v_transaction_count NUMBER := 1000000;
    v_random_date DATE;
    v_random_customer VARCHAR2(20);
BEGIN
    -- 1. 고객 데이터 삽입 (1000명)
    FOR i IN 1..v_customer_count LOOP
            INSERT INTO 고객 (고객번호, 고객명, 가입일시)
            VALUES (
                       'CUST' || LPAD(i, 6, '0'),
                       '고객' || i,
                       v_start_date + DBMS_RANDOM.VALUE(0, 1000) + DBMS_RANDOM.VALUE(0, 1)
                   );

            -- 1000건마다 커밋
            IF MOD(i, 1000) = 0 THEN
                COMMIT;
            END IF;
        END LOOP;
    COMMIT;

    DBMS_OUTPUT.PUT_LINE('고객 데이터 삽입 완료: ' || v_customer_count || '건');

    -- 2. 거래 데이터 삽입 (100만건)
    FOR i IN 1..v_transaction_count LOOP
            -- 랜덤 고객번호 선택 (1~1000)
            v_random_customer := 'CUST' || LPAD(TRUNC(DBMS_RANDOM.VALUE(1, v_customer_count + 1)), 6, '0');

            -- 랜덤 날짜 생성 (1년 범위)
            v_random_date := v_start_date + DBMS_RANDOM.VALUE(0, 1000) + DBMS_RANDOM.VALUE(0, 1);

            INSERT INTO 거래 (거래번호, 고객번호, 거래일시, 거래금액)
            VALUES (
                       'TXN' || LPAD(i, 10, '0'),
                       v_random_customer,
                       v_random_date,
                       ROUND(DBMS_RANDOM.VALUE(1000, 1000000), -2)  -- 1,000원 ~ 1,000,000원 (100원 단위)
                   );

            -- 10000건마다 커밋 (성능 최적화)
            IF MOD(i, 10000) = 0 THEN
                COMMIT;
                DBMS_OUTPUT.PUT_LINE('거래 데이터 삽입 중: ' || i || '건');
            END IF;
        END LOOP;
    COMMIT;

    DBMS_OUTPUT.PUT_LINE('거래 데이터 삽입 완료: ' || v_transaction_count || '건');

    -- 통계 정보 수집 (옵티마이저 성능 향상)
    DBMS_STATS.GATHER_TABLE_STATS(USER, '고객');
    DBMS_STATS.GATHER_TABLE_STATS(USER, '거래');

    DBMS_OUTPUT.PUT_LINE('통계 정보 수집 완료');
END;
/

-- 데이터 확인
SELECT COUNT(*) AS 고객수 FROM 고객;
SELECT COUNT(*) AS 거래수 FROM 거래;

-- 샘플 데이터 확인
SELECT * FROM 고객 WHERE ROWNUM <= 5;
SELECT * FROM 거래 WHERE ROWNUM <= 5;

-- 문제 쿼리
SELECT C.고객번호, C.고객명
     , (SELECT ROUND(AVG(거래금액), 2) 평균거래금액
        FROM 거래
        WHERE 거래일시 >= TRUNC(SYSDATE, 'MM')
          AND 고객번호 = C.고객번호)
FROM 고객 C
WHERE C.가입일시 >= TRUNC(ADD_MONTHS(SYSDATE, -1), 'MM');

-- 인덱스 생성 후 NO_UNNEST
CREATE INDEX 고객_X1 ON 고객(가입일시);
CREATE INDEX 거래_X2 ON 거래(고객번호, 거래일시);

SELECT C.고객번호, C.고객명
     , (SELECT /*+ NO_UNNEST */ ROUND(AVG(거래금액), 2) 평균거래금액
        FROM 거래
        WHERE 거래일시 >= TRUNC(SYSDATE, 'MM')
          AND 고객번호 = C.고객번호)
FROM 고객 C
WHERE C.가입일시 >= TRUNC(ADD_MONTHS(SYSDATE, -1), 'MM');

-- 조건조건 PUSHDOWN
SELECT /*+ ORDERED USE_NL(T) */ C.고객번호, C.고객명, T.평균거래금액
FROM 고객 C, (SELECT /*+ NO_MERGE PUSH_PRED */ 고객번호, ROUND(AVG(거래금액), 2) 평균거래금액
             FROM 거래
             WHERE 거래일시 >= TRUNC(SYSDATE, 'MM')
             GROUP BY 고객번호) T
WHERE C.가입일시 >= TRUNC(ADD_MONTHS(SYSDATE, -1), 'MM')
AND T.고객번호(+) = C.고객번호;