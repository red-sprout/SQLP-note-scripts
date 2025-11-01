-- 기존 테이블 삭제
DROP TABLE IF EXISTS 주문상품 CASCADE CONSTRAINTS;
DROP TABLE IF EXISTS 상품 CASCADE CONSTRAINTS;

-- 상품 테이블 생성
CREATE TABLE 상품 (
                    상품코드 VARCHAR2(20),
                    상품명 VARCHAR2(20),
                    상품가격 NUMBER,
                    CONSTRAINT 상품_PK PRIMARY KEY (상품코드)
);

-- 주문상품 테이블 생성 (월 단위 파티션)
CREATE TABLE 주문상품 (
                      고객번호 VARCHAR2(20),
                      상품코드 VARCHAR2(20),
                      주문일시 TIMESTAMP,
                      할인유형코드 VARCHAR2(4),
                      주문수량 NUMBER,
                      주문금액 NUMBER,
                      CONSTRAINT 주문상품_PK PRIMARY KEY (고객번호, 상품코드, 주문일시)
)
    PARTITION BY RANGE (주문일시)
    INTERVAL (NUMTOYMINTERVAL(1, 'MONTH'))
(
    PARTITION P_INITIAL VALUES LESS THAN (TIMESTAMP '2015-11-01 00:00:00')
);

-- 로컬 인덱스 생성
CREATE INDEX 주문상품_X1 ON 주문상품(주문일시, 할인유형코드) LOCAL;

-- 데이터 생성
DECLARE
    v_start_date DATE := ADD_MONTHS(SYSDATE, -120);  -- 10년 전
    v_product_count NUMBER := 200;                    -- 상품 200개
    v_customer_count NUMBER := 100;                   -- 고객 100명
    v_orders_per_month NUMBER := 10000;               -- 월 1만건
    v_months NUMBER := 120;                           -- 120개월
    v_discount_ratio NUMBER := 0.2;                   -- K890 비율 20%

    v_random_product VARCHAR2(20);
    v_random_customer VARCHAR2(20);
    v_order_date TIMESTAMP;
    v_discount_code VARCHAR2(4);
    v_base_price NUMBER;
    v_order_quantity NUMBER;
    v_order_amount NUMBER;
    v_month_start DATE;
    v_counter NUMBER := 0;
    v_total_counter NUMBER := 0;

BEGIN
    -- 1. 상품 데이터 생성 (200개)
    DBMS_OUTPUT.PUT_LINE('=== 상품 데이터 생성 시작 ===');
    FOR i IN 1..v_product_count LOOP
            INSERT INTO 상품 (상품코드, 상품명, 상품가격)
            VALUES (
                       'PROD' || LPAD(i, 4, '0'),
                       '상품' || i,
                       ROUND(DBMS_RANDOM.VALUE(10000, 100000), -3)
                   );
        END LOOP;
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('상품 데이터 생성 완료: ' || v_product_count || '건');

    -- 2. 주문상품 데이터 생성 (월별 1만건씩 120개월)
    DBMS_OUTPUT.PUT_LINE('=== 주문상품 데이터 생성 시작 ===');
    DBMS_OUTPUT.PUT_LINE('총 ' || (v_orders_per_month * v_months) || '건 생성 예정');

    -- 월별로 데이터 생성
    FOR month_idx IN 0..(v_months - 1) LOOP
            v_month_start := ADD_MONTHS(v_start_date, month_idx);
            v_counter := 0;

            DBMS_OUTPUT.PUT_LINE(
                    TO_CHAR(v_month_start, 'YYYY-MM') || ' 월 데이터 생성 시작...'
            );

            -- 해당 월에 1만건 생성
            FOR i IN 1..v_orders_per_month LOOP
                    -- 해당 월 내의 랜덤 날짜/시간
                    v_order_date := v_month_start +
                                    DBMS_RANDOM.VALUE(0, 28) +  -- 28일 이내 (모든 월에 안전)
                                    NUMTODSINTERVAL(DBMS_RANDOM.VALUE(0, 86400), 'SECOND');

                    -- 상품 200개를 고르게 분포시키기 위해
                    -- 순환 방식 + 약간의 랜덤성
                    IF i <= 5000 THEN
                        -- 전반부 5000건: 순환 방식으로 모든 상품 골고루
                        v_random_product := 'PROD' || LPAD(MOD(i - 1, v_product_count) + 1, 4, '0');
                    ELSE
                        -- 후반부 5000건: 완전 랜덤
                        v_random_product := 'PROD' || LPAD(TRUNC(DBMS_RANDOM.VALUE(1, v_product_count + 1)), 4, '0');
                    END IF;

                    -- 랜덤 고객
                    v_random_customer := 'CUST' || LPAD(TRUNC(DBMS_RANDOM.VALUE(1, v_customer_count + 1)), 4, '0');

                    -- 주문수량 (1~10개)
                    v_order_quantity := TRUNC(DBMS_RANDOM.VALUE(1, 11));

                    -- 할인유형코드: 20%는 'K890', 80%는 K000~K999 랜덤
                    IF DBMS_RANDOM.VALUE < v_discount_ratio THEN
                        v_discount_code := 'K890';
                        v_base_price := ROUND(DBMS_RANDOM.VALUE(10000, 100000), -3);
                        v_order_amount := v_base_price * v_order_quantity * 0.9;
                    ELSE
                        LOOP
                            v_discount_code := 'K' || LPAD(TRUNC(DBMS_RANDOM.VALUE(0, 1000)), 3, '0');
                            EXIT WHEN v_discount_code != 'K890';
                        END LOOP;
                        v_base_price := ROUND(DBMS_RANDOM.VALUE(10000, 100000), -3);
                        v_order_amount := v_base_price * v_order_quantity;
                    END IF;

                    -- INSERT (PK 중복 시 무시)
                    BEGIN
                        INSERT INTO 주문상품 (고객번호, 상품코드, 주문일시, 할인유형코드, 주문수량, 주문금액)
                        VALUES (
                                   v_random_customer,
                                   v_random_product,
                                   v_order_date,
                                   v_discount_code,
                                   v_order_quantity,
                                   v_order_amount
                               );
                        v_counter := v_counter + 1;
                        v_total_counter := v_total_counter + 1;

                    EXCEPTION
                        WHEN DUP_VAL_ON_INDEX THEN
                            NULL;
                    END;

                    -- 1000건마다 커밋
                    IF MOD(i, 1000) = 0 THEN
                        COMMIT;
                    END IF;

                END LOOP;

            COMMIT;
            DBMS_OUTPUT.PUT_LINE(
                    TO_CHAR(v_month_start, 'YYYY-MM') || ' 월 완료: ' ||
                    v_counter || '건 (누적: ' || v_total_counter || '건)'
            );

            -- 10개월마다 통계 수집
            IF MOD(month_idx + 1, 10) = 0 THEN
                DBMS_OUTPUT.PUT_LINE('=== 중간 통계 수집 (' || (month_idx + 1) || '개월) ===');
                DBMS_STATS.GATHER_TABLE_STATS(USER, '주문상품');
            END IF;

        END LOOP;

    DBMS_OUTPUT.PUT_LINE('=== 주문상품 데이터 생성 완료 ===');
    DBMS_OUTPUT.PUT_LINE('총 삽입 건수: ' || v_total_counter || '건');

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
            COUNT(DISTINCT TO_CHAR(주문일시, 'YYYY-MM')) as 월수,
            COUNT(CASE WHEN 할인유형코드 = 'K890' THEN 1 END) as K890건수,
            ROUND(COUNT(CASE WHEN 할인유형코드 = 'K890' THEN 1 END) / COUNT(*) * 100, 2) as K890비율,
            MIN(주문일시) as 최초주문일,
            MAX(주문일시) as 최근주문일
        FROM 주문상품
        ) LOOP
            DBMS_OUTPUT.PUT_LINE('총 주문 건수: ' || rec.총주문건수);
            DBMS_OUTPUT.PUT_LINE('상품 종류 수: ' || rec.상품종류수);
            DBMS_OUTPUT.PUT_LINE('데이터 기간(월): ' || rec.월수);
            DBMS_OUTPUT.PUT_LINE('K890 건수: ' || rec.K890건수);
            DBMS_OUTPUT.PUT_LINE('K890 비율: ' || rec.K890비율 || '%');
            DBMS_OUTPUT.PUT_LINE('최초 주문일: ' || TO_CHAR(rec.최초주문일, 'YYYY-MM-DD HH24:MI:SS'));
            DBMS_OUTPUT.PUT_LINE('최근 주문일: ' || TO_CHAR(rec.최근주문일, 'YYYY-MM-DD HH24:MI:SS'));
        END LOOP;

END;
/

SELECT 상품코드, 상품명, 상품가격, 총주문수량, 총주문금액
FROM (
         SELECT P.상품코드, MIN(P.상품명) 상품명, MIN(P.상품가격) 상품가격
              , SUM(O.주문수량) 총주문수량, SUM(O.주문금액) 총주문금액
         FROM 주문상품 O, 상품 P
         WHERE O.주문일시 >= ADD_MONTHS(SYSDATE, -1)
           AND O.할인유형코드 = 'K890'
           AND P.상품코드 = O.상품코드
         GROUP BY P.상품코드
         ORDER BY 총주문금액 DESC, 상품코드
     )
WHERE ROWNUM <= 100;

SELECT /*+ LEADING(O P) USE_NL(P) */ P.상품코드, P.상품명, P.상품가격, O.총주문수량, O.총주문금액
FROM (
         SELECT /*+ FULL(주문상품) */ 상품코드, SUM(주문수량) 총주문수량, SUM(주문금액) 총주문금액
         FROM 주문상품
         WHERE 주문일시 >= ADD_MONTHS(SYSDATE, -1)
           AND 할인유형코드 = 'K890'
         GROUP BY 상품코드
         ORDER BY 총주문금액 DESC, 상품코드
     ) O, 상품 P
WHERE P.상품코드 = O.상품코드
AND ROWNUM <= 100
ORDER BY 총주문금액 DESC, 상품코드;

SELECT /*+ LEADING(O P) USE_NL(P) NO_NLJ_BATCHING(P) */ P.상품코드, P.상품명, P.상품가격, O.총주문수량, O.총주문금액
FROM (
         SELECT /*+ FULL(주문상품) */ 상품코드, SUM(주문수량) 총주문수량, SUM(주문금액) 총주문금액
         FROM 주문상품
         WHERE 주문일시 >= ADD_MONTHS(SYSDATE, -1)
           AND 할인유형코드 = 'K890'
         GROUP BY 상품코드
         ORDER BY 총주문금액 DESC, 상품코드
     ) O, 상품 P
WHERE P.상품코드 = O.상품코드
  AND ROWNUM <= 100;