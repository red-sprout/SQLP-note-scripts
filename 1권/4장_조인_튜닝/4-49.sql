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
    v_product_count NUMBER := 2000;                   -- 상품 2000개
    v_k890_product_count NUMBER := 10;                -- K890 판매 상품 10개
    v_customer_count NUMBER := 1000;                  -- 고객 1000명
    v_orders_per_month NUMBER := 100000;              -- 월 10만건
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
    v_k890_orders_per_month NUMBER;
    v_normal_orders_per_month NUMBER;

BEGIN
    -- K890 상품은 10개, 나머지 상품은 1990개
    v_k890_orders_per_month := v_orders_per_month * v_discount_ratio;  -- 월 2만건
    v_normal_orders_per_month := v_orders_per_month - v_k890_orders_per_month;  -- 월 8만건

    -- 1. 상품 데이터 생성 (2000개)
    DBMS_OUTPUT.PUT_LINE('=== 상품 데이터 생성 시작 ===');
    FOR i IN 1..v_product_count LOOP
            INSERT INTO 상품 (상품코드, 상품명, 상품가격)
            VALUES (
                       'PROD' || LPAD(i, 5, '0'),
                       '상품' || i,
                       ROUND(DBMS_RANDOM.VALUE(10000, 100000), -3)
                   );
        END LOOP;
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('상품 데이터 생성 완료: ' || v_product_count || '건');
    DBMS_OUTPUT.PUT_LINE('  - K890 판매 상품: PROD00001 ~ PROD00010 (10개)');
    DBMS_OUTPUT.PUT_LINE('  - 일반 판매 상품: PROD00011 ~ PROD02000 (1990개)');

    -- 2. 주문상품 데이터 생성 (월별 10만건씩 120개월)
    DBMS_OUTPUT.PUT_LINE('=== 주문상품 데이터 생성 시작 ===');
    DBMS_OUTPUT.PUT_LINE('총 ' || (v_orders_per_month * v_months) || '건 생성 예정 (약 30-60분 소요)');

    -- 월별로 데이터 생성
    FOR month_idx IN 0..(v_months - 1) LOOP
            v_month_start := ADD_MONTHS(v_start_date, month_idx);
            v_counter := 0;

            DBMS_OUTPUT.PUT_LINE(
                    TO_CHAR(v_month_start, 'YYYY-MM') || ' 월 데이터 생성 시작...'
            );

            -- ========================================
            -- A. K890 할인 주문 생성 (2만건, 상품 10개만)
            -- ========================================
            FOR i IN 1..v_k890_orders_per_month LOOP
                    -- 해당 월 내의 랜덤 날짜/시간
                    v_order_date := v_month_start +
                                    DBMS_RANDOM.VALUE(0, 28) +
                                    NUMTODSINTERVAL(DBMS_RANDOM.VALUE(0, 86400), 'SECOND');

                    -- K890 판매 상품 10개 중 랜덤 선택 (PROD00001 ~ PROD00010)
                    v_random_product := 'PROD' || LPAD(TRUNC(DBMS_RANDOM.VALUE(1, 11)), 5, '0');

                    -- 랜덤 고객
                    v_random_customer := 'CUST' || LPAD(TRUNC(DBMS_RANDOM.VALUE(1, v_customer_count + 1)), 5, '0');

                    -- 주문수량 (1~10개)
                    v_order_quantity := TRUNC(DBMS_RANDOM.VALUE(1, 11));

                    -- K890 할인 적용
                    v_discount_code := 'K890';
                    v_base_price := ROUND(DBMS_RANDOM.VALUE(10000, 100000), -3);
                    v_order_amount := v_base_price * v_order_quantity * 0.9;  -- 10% 할인

                    -- INSERT
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

                    -- 5000건마다 커밋
                    IF MOD(i, 5000) = 0 THEN
                        COMMIT;
                    END IF;
                END LOOP;

            -- ========================================
            -- B. 일반 주문 생성 (8만건, 나머지 1990개 상품)
            -- ========================================
            FOR i IN 1..v_normal_orders_per_month LOOP
                    -- 해당 월 내의 랜덤 날짜/시간
                    v_order_date := v_month_start +
                                    DBMS_RANDOM.VALUE(0, 28) +
                                    NUMTODSINTERVAL(DBMS_RANDOM.VALUE(0, 86400), 'SECOND');

                    -- 일반 상품 1990개 중 랜덤 선택 (PROD00011 ~ PROD02000)
                    v_random_product := 'PROD' || LPAD(TRUNC(DBMS_RANDOM.VALUE(11, v_product_count + 1)), 5, '0');

                    -- 랜덤 고객
                    v_random_customer := 'CUST' || LPAD(TRUNC(DBMS_RANDOM.VALUE(1, v_customer_count + 1)), 5, '0');

                    -- 주문수량 (1~10개)
                    v_order_quantity := TRUNC(DBMS_RANDOM.VALUE(1, 11));

                    -- K890이 아닌 랜덤 할인코드
                    LOOP
                        v_discount_code := 'K' || LPAD(TRUNC(DBMS_RANDOM.VALUE(0, 1000)), 3, '0');
                        EXIT WHEN v_discount_code != 'K890';
                    END LOOP;

                    v_base_price := ROUND(DBMS_RANDOM.VALUE(10000, 100000), -3);
                    v_order_amount := v_base_price * v_order_quantity;  -- 할인 없음

                    -- INSERT
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

                    -- 5000건마다 커밋
                    IF MOD(i, 5000) = 0 THEN
                        COMMIT;
                    END IF;
                END LOOP;

            COMMIT;
            DBMS_OUTPUT.PUT_LINE(
                    TO_CHAR(v_month_start, 'YYYY-MM') || ' 월 완료: ' ||
                    v_counter || '건 (누적: ' || v_total_counter || '건, ' ||
                    ROUND(v_total_counter / (v_orders_per_month * v_months) * 100, 1) || '%)'
            );

            -- 12개월마다 통계 수집
            IF MOD(month_idx + 1, 12) = 0 THEN
                DBMS_OUTPUT.PUT_LINE('=== 중간 통계 수집 (' || (month_idx + 1) || '개월) ===');
                DBMS_STATS.GATHER_TABLE_STATS(USER, '주문상품', estimate_percent => 10);
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
            COUNT(DISTINCT 상품코드) as 주문된_상품종류수,
            COUNT(DISTINCT TO_CHAR(주문일시, 'YYYY-MM')) as 월수,
            COUNT(CASE WHEN 할인유형코드 = 'K890' THEN 1 END) as K890건수,
            ROUND(COUNT(CASE WHEN 할인유형코드 = 'K890' THEN 1 END) / COUNT(*) * 100, 2) as K890비율,
            MIN(주문일시) as 최초주문일,
            MAX(주문일시) as 최근주문일
        FROM 주문상품
        ) LOOP
            DBMS_OUTPUT.PUT_LINE('총 주문 건수: ' || TO_CHAR(rec.총주문건수, '999,999,999'));
            DBMS_OUTPUT.PUT_LINE('주문된 상품 종류: ' || rec.주문된_상품종류수);
            DBMS_OUTPUT.PUT_LINE('데이터 기간(월): ' || rec.월수);
            DBMS_OUTPUT.PUT_LINE('K890 건수: ' || TO_CHAR(rec.K890건수, '999,999,999'));
            DBMS_OUTPUT.PUT_LINE('K890 비율: ' || rec.K890비율 || '%');
            DBMS_OUTPUT.PUT_LINE('최초 주문일: ' || TO_CHAR(rec.최초주문일, 'YYYY-MM-DD'));
            DBMS_OUTPUT.PUT_LINE('최근 주문일: ' || TO_CHAR(rec.최근주문일, 'YYYY-MM-DD'));
        END LOOP;

    -- K890 상품 확인
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('=== K890으로 판매된 상품 확인 ===');
    FOR rec IN (
        SELECT 상품코드, COUNT(*) as 주문건수
        FROM 주문상품
        WHERE 할인유형코드 = 'K890'
        GROUP BY 상품코드
        ORDER BY 상품코드
        ) LOOP
            DBMS_OUTPUT.PUT_LINE('상품: ' || rec.상품코드 || ' - 주문건수: ' || TO_CHAR(rec.주문건수, '999,999,999'));
        END LOOP;

END;
/

-- ========================================
-- 검증 쿼리
-- ========================================

-- 1. 전체 데이터 확인
SELECT COUNT(*) as 총주문건수 FROM 주문상품;
SELECT COUNT(*) as 상품수 FROM 상품;

-- 2. 월별 데이터 분포
SELECT
    TO_CHAR(주문일시, 'YYYY-MM') as 년월,
    COUNT(*) as 건수,
    COUNT(CASE WHEN 할인유형코드 = 'K890' THEN 1 END) as K890건수
FROM 주문상품
GROUP BY TO_CHAR(주문일시, 'YYYY-MM')
ORDER BY 년월
    FETCH FIRST 12 ROWS ONLY;

-- 3. K890 상품 확인
SELECT
    상품코드,
    COUNT(*) as 주문건수,
    SUM(주문수량) as 총수량
FROM 주문상품
WHERE 할인유형코드 = 'K890'
GROUP BY 상품코드
ORDER BY 상품코드;

-- 4. K890 비율 확인
SELECT
    할인유형코드,
    COUNT(*) as 건수,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) as 비율
FROM 주문상품
GROUP BY 할인유형코드
HAVING 할인유형코드 = 'K890' OR ROWNUM <= 10
ORDER BY 건수 DESC;

-- 5. 파티션 정보 확인
SELECT
    partition_name,
    high_value,
    num_rows,
    TO_CHAR(num_rows, '999,999,999') as 건수
FROM user_tab_partitions
WHERE table_name = '주문상품'
ORDER BY partition_position DESC
    FETCH FIRST 12 ROWS ONLY;

-- 6. 최근 1개월 데이터 확인
SELECT
    COUNT(*) as 최근1개월_건수,
    COUNT(CASE WHEN 할인유형코드 = 'K890' THEN 1 END) as K890_건수,
    COUNT(DISTINCT 상품코드) as 상품종류수,
    COUNT(DISTINCT CASE WHEN 할인유형코드 = 'K890' THEN 상품코드 END) as K890_상품수
FROM 주문상품
WHERE 주문일시 >= ADD_MONTHS(SYSDATE, -1);

-- 7. 파티션 프루닝 확인
EXPLAIN PLAN FOR
SELECT /*+ INDEX(주문상품 주문상품_X1) */
    COUNT(*), SUM(주문금액)
FROM 주문상품
WHERE 주문일시 >= ADD_MONTHS(SYSDATE, -1)
  AND 할인유형코드 = 'K890';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(FORMAT => 'BASIC +PARTITION'));

SELECT /*+ LEADING(O P) USE_NL(P) */
    P.상품코드, P.상품명, P.상품가격, O.총주문수량, O.총주문금액
FROM (SELECT /*+ NO_MERGE FULL(주문상품) */
          상품코드, SUM(주문수량) 총주문수량, SUM(주문금액) 총주문금액
      FROM 주문상품
      WHERE 주문일시 >= ADD_MONTHS(SYSDATE, -1)
        AND 할인유형코드 = 'K890'
      GROUP BY 상품코드) O, 상품 P
WHERE P.상품코드 = O.상품코드
ORDER BY O.총주문금액 DESC, P.상품코드;