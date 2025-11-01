DROP TABLE IF EXISTS 상품;
DROP TABLE IF EXISTS 주문상품;

CREATE TABLE 상품 (
                    상품코드 VARCHAR2(20),
                    상품명 VARCHAR2(20),
                    상품가격 NUMBER,
                    CONSTRAINT 상품_PK PRIMARY KEY (상품코드)
);

CREATE TABLE 주문상품 (
                      고객번호 VARCHAR2(20),
                      상품코드 VARCHAR2(20),
                      주문일시 TIMESTAMP,
                      할인유형코드 VARCHAR2(4),
                      주문수량 NUMBER,
                      주문금액 NUMBER,
                      CONSTRAINT 주문상품_PK PRIMARY KEY (고객번호, 상품코드, 주문일시)
);

CREATE INDEX 주문상품_X1 ON 주문상품(주문일시, 할인유형코드);

-- 데이터 생성
DECLARE
    v_start_date DATE := ADD_MONTHS(SYSDATE, -120);  -- 10년 전
    v_product_count NUMBER := 200;                    -- 상품 200개
    v_customer_count NUMBER := 100;                   -- 고객 100명 (재사용)
    v_total_orders NUMBER := 1200000;                 -- 120만건
    v_discount_ratio NUMBER := 0.2;                   -- 할인 20%
    v_commit_interval NUMBER := 10000;                -- 1만건마다 커밋

    v_random_product VARCHAR2(20);
    v_random_customer VARCHAR2(20);
    v_random_date TIMESTAMP;
    v_discount_code VARCHAR2(4);
    v_base_price NUMBER;
    v_order_quantity NUMBER;
    v_order_amount NUMBER;
    v_counter NUMBER := 0;

BEGIN
    -- 1. 상품 데이터 생성 (200개)
    DBMS_OUTPUT.PUT_LINE('=== 상품 데이터 생성 시작 ===');
    FOR i IN 1..v_product_count LOOP
            INSERT INTO 상품 (상품코드, 상품명, 상품가격)
            VALUES (
                       'PROD' || LPAD(i, 4, '0'),
                       '상품' || i,
                       ROUND(DBMS_RANDOM.VALUE(1000, 100000), -3)  -- 1천원 ~ 10만원
                   );
        END LOOP;
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('상품 데이터 생성 완료: ' || v_product_count || '건');

    -- 2. 주문상품 데이터 생성 (120만건)
    DBMS_OUTPUT.PUT_LINE('=== 주문상품 데이터 생성 시작 ===');
    DBMS_OUTPUT.PUT_LINE('총 ' || v_total_orders || '건 생성 예정 (약 5-10분 소요)');

    FOR i IN 1..v_total_orders LOOP
            -- 랜덤 상품 선택 (200개 중)
            v_random_product := 'PROD' || LPAD(TRUNC(DBMS_RANDOM.VALUE(1, v_product_count + 1)), 4, '0');

            -- 랜덤 고객 선택 (100명 재사용)
            v_random_customer := 'CUST' || LPAD(TRUNC(DBMS_RANDOM.VALUE(1, v_customer_count + 1)), 4, '0');

            -- 10년 범위의 랜덤 날짜 (120개월)
            v_random_date := v_start_date + DBMS_RANDOM.VALUE(0, 3650) +
                             DBMS_RANDOM.VALUE(0, 1) +
                             NUMTODSINTERVAL(DBMS_RANDOM.VALUE(0, 86400), 'SECOND');

            -- 주문수량 (1~10개)
            v_order_quantity := TRUNC(DBMS_RANDOM.VALUE(1, 11));

            -- 할인유형코드: 20%는 'K890', 80%는 K000~K999 랜덤 (K890 제외)
            IF DBMS_RANDOM.VALUE < v_discount_ratio THEN
                v_discount_code := 'K890';  -- 할인 대상 (20%)
                v_base_price := ROUND(DBMS_RANDOM.VALUE(10000, 100000), -3);
                v_order_amount := v_base_price * v_order_quantity * 0.9;  -- 10% 할인
            ELSE
                -- K000~K999 중 K890을 제외한 랜덤 코드
                LOOP
                    v_discount_code := 'K' || LPAD(TRUNC(DBMS_RANDOM.VALUE(0, 1000)), 3, '0');
                    EXIT WHEN v_discount_code != 'K890';  -- K890이 아니면 탈출
                END LOOP;
                v_base_price := ROUND(DBMS_RANDOM.VALUE(10000, 100000), -3);
                v_order_amount := v_base_price * v_order_quantity;  -- 할인 없음
            END IF;

            -- 주문상품 INSERT (PK 중복 시 재시도)
            BEGIN
                INSERT INTO 주문상품 (고객번호, 상품코드, 주문일시, 할인유형코드, 주문수량, 주문금액)
                VALUES (
                           v_random_customer,
                           v_random_product,
                           v_random_date,
                           v_discount_code,
                           v_order_quantity,
                           v_order_amount
                       );

                v_counter := v_counter + 1;

            EXCEPTION
                WHEN DUP_VAL_ON_INDEX THEN
                    -- PK 중복 시 무시하고 계속 (드물게 발생)
                    NULL;
            END;

            -- 진행상황 출력 및 커밋
            IF MOD(i, v_commit_interval) = 0 THEN
                COMMIT;
                DBMS_OUTPUT.PUT_LINE(
                        TO_CHAR(SYSDATE, 'HH24:MI:SS') || ' - ' ||
                        '처리: ' || i || '건 / 삽입: ' || v_counter || '건 (' ||
                        ROUND(i / v_total_orders * 100, 2) || '%)'
                );
            END IF;

        END LOOP;

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('=== 주문상품 데이터 생성 완료 ===');
    DBMS_OUTPUT.PUT_LINE('실제 삽입 건수: ' || v_counter || '건');

    -- 3. 최종 통계 수집
    DBMS_OUTPUT.PUT_LINE('=== 최종 통계 수집 시작 ===');
    DBMS_STATS.GATHER_TABLE_STATS(USER, '상품');
    DBMS_STATS.GATHER_TABLE_STATS(USER, '주문상품');
    DBMS_OUTPUT.PUT_LINE('=== 최종 통계 수집 완료 ===');

    -- 4. 데이터 검증
    DBMS_OUTPUT.PUT_LINE('=== 데이터 검증 ===');

    FOR rec IN (
        SELECT
            COUNT(*) as 총주문건수,
            COUNT(DISTINCT 상품코드) as 상품종류수,
            COUNT(DISTINCT 할인유형코드) as 할인유형수,
            COUNT(CASE WHEN 할인유형코드 = 'K890' THEN 1 END) as K890건수,
            ROUND(COUNT(CASE WHEN 할인유형코드 = 'K890' THEN 1 END) / COUNT(*) * 100, 2) as K890비율,
            MIN(주문일시) as 최초주문일,
            MAX(주문일시) as 최근주문일,
            SUM(주문수량) as 총주문수량,
            SUM(주문금액) as 총주문금액
        FROM 주문상품
        ) LOOP
            DBMS_OUTPUT.PUT_LINE('총 주문 건수: ' || rec.총주문건수);
            DBMS_OUTPUT.PUT_LINE('상품 종류 수: ' || rec.상품종류수);
            DBMS_OUTPUT.PUT_LINE('할인유형 종류 수: ' || rec.할인유형수);
            DBMS_OUTPUT.PUT_LINE('K890 건수: ' || rec.K890건수);
            DBMS_OUTPUT.PUT_LINE('K890 비율: ' || rec.K890비율 || '%');
            DBMS_OUTPUT.PUT_LINE('총 주문 수량: ' || rec.총주문수량);
            DBMS_OUTPUT.PUT_LINE('총 주문 금액: ' || TO_CHAR(rec.총주문금액, '999,999,999,999'));
            DBMS_OUTPUT.PUT_LINE('최초 주문일: ' || TO_CHAR(rec.최초주문일, 'YYYY-MM-DD HH24:MI:SS'));
            DBMS_OUTPUT.PUT_LINE('최근 주문일: ' || TO_CHAR(rec.최근주문일, 'YYYY-MM-DD HH24:MI:SS'));
        END LOOP;

END;
/

-- 데이터 확인 쿼리
SELECT COUNT(*) as 상품수 FROM 상품;
SELECT COUNT(*) as 주문건수 FROM 주문상품;

-- 할인유형코드별 분포 확인 (상위 20개)
SELECT 할인유형코드, COUNT(*) as 건수,
       ROUND(COUNT(*) / SUM(COUNT(*)) OVER () * 100, 2) as 비율
FROM 주문상품
GROUP BY 할인유형코드
ORDER BY 건수 DESC
    FETCH FIRST 20 ROWS ONLY;

-- K890 확인
SELECT 할인유형코드, COUNT(*) as 건수,
       ROUND(COUNT(*) / (SELECT COUNT(*) FROM 주문상품) * 100, 2) as 비율
FROM 주문상품
WHERE 할인유형코드 = 'K890'
GROUP BY 할인유형코드;

-- 상품별 주문 고른 분포 확인
SELECT
    COUNT(DISTINCT 상품코드) as 주문된_상품수,
    MIN(주문건수) as 최소주문건수,
    MAX(주문건수) as 최대주문건수,
    ROUND(AVG(주문건수), 2) as 평균주문건수,
    ROUND(STDDEV(주문건수), 2) as 표준편차
FROM (
         SELECT 상품코드, COUNT(*) as 주문건수
         FROM 주문상품
         GROUP BY 상품코드
     );

-- 월별 주문 분포 확인
SELECT
    TO_CHAR(주문일시, 'YYYY-MM') as 년월,
    COUNT(*) as 주문건수
FROM 주문상품
GROUP BY TO_CHAR(주문일시, 'YYYY-MM')
ORDER BY 년월
    FETCH FIRST 12 ROWS ONLY;

-- 문제 쿼리
SELECT P.상품코드, MIN(P.상품명) 상품명, MIN(P.상품가격) 상품가격
     , SUM(O.주문수량) 총주문수량, SUM(O.주문금액) 총주문금액
FROM 주문상품 O, 상품 P
WHERE O.주문일시 >= ADD_MONTHS(SYSDATE, -1)
  AND O.할인유형코드 = 'K890'
  AND P.상품코드 = O.상품코드
GROUP BY P.상품코드
ORDER BY 총주문금액 DESC, 상품코드;

--인덱스는 선행컬럼이 등호여야 함
DROP INDEX 주문상품_X1;
CREATE INDEX 주문상품_X1 ON 주문상품(할인유형코드, 주문일시);

--1안 : 상품코드로 묶고 이를 JOIN 하는 방법 - 쿼리 자체의 수정
SELECT /*+ LEADING(O P) USE_HASH(P) FULL(P) */
    P.상품코드, P.상품명, P.상품가격, O.총주문수량, O.총주문금액
FROM (SELECT /*+ NO_MERGE INDEX(주문상품 주문상품_X1) */
          상품코드, SUM(주문수량) 총주문수량, SUM(주문금액) 총주문금액
      FROM 주문상품
      WHERE 주문일시 >= ADD_MONTHS(SYSDATE, -1)
        AND 할인유형코드 = 'K890'
      GROUP BY 상품코드) O, 상품 P
WHERE P.상품코드 = O.상품코드
ORDER BY O.총주문금액 DESC, P.상품코드;

--2안 : 힌트만으로 사용
SELECT /*+ LEADING(P O) USE_HASH(O) FULL(P) INDEX(O 주문상품_X1) */
    P.상품코드, MIN(P.상품명) 상품명, MIN(P.상품가격) 상품가격
     , SUM(O.주문수량) 총주문수량, SUM(O.주문금액) 총주문금액
FROM 주문상품 O, 상품 P
WHERE O.주문일시 >= ADD_MONTHS(SYSDATE, -1)
  AND O.할인유형코드 = 'K890'
  AND P.상품코드 = O.상품코드
GROUP BY P.상품코드
ORDER BY 총주문금액 DESC, 상품코드;