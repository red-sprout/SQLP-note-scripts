DROP TABLE IF EXISTS 주문상품 CASCADE CONSTRAINTS;
DROP TABLE IF EXISTS 주문 CASCADE CONSTRAINTS;
DROP SEQUENCE IF EXISTS 주문번호_SEQ;

CREATE TABLE 주문 (
                    주문번호 NUMBER NOT NULL,
                    주문일자 DATE NOT NULL,
                    주문시각 TIMESTAMP NOT NULL,
                    고객번호 NUMBER NOT NULL,
                    결제금액 NUMBER NOT NULL,
                    결제수단코드 VARCHAR2(5),
                    배송주소 VARCHAR2(200),
                    CONSTRAINT 주문_PK PRIMARY KEY (주문번호)
);

CREATE TABLE 주문상품 (
                      주문번호 NUMBER NOT NULL,
                      상품코드 VARCHAR2(5) NOT NULL,
                      주문일자 DATE NOT NULL,
                      주문시각 TIMESTAMP NOT NULL,
                      주문가격 NUMBER NOT NULL,
                      주문수량 NUMBER NOT NULL,
                      주문금액 NUMBER NOT NULL,
                      할인율 NUMBER NULL,
                      CONSTRAINT 주문상품_PK PRIMARY KEY (주문번호, 상품코드)
);

CREATE SEQUENCE 주문번호_SEQ START WITH 1 INCREMENT BY 1;

COMMIT;

DECLARE
    v_주문번호 NUMBER;
    v_주문일자 DATE := TRUNC(SYSDATE);
    v_고객번호 NUMBER;
    v_상품코드 VARCHAR2(5);
    v_주문가격 NUMBER;
    v_주문수량 NUMBER;
    v_주문금액 NUMBER;
    v_할인율 NUMBER;
    v_결제금액 NUMBER;

    v_상품수 NUMBER;
    v_총주문건수 NUMBER := 1000000;
    v_일평균상품수 NUMBER := 10000;

    v_commit_cnt NUMBER := 0;
    v_start_time NUMBER;
    v_end_time NUMBER;

    TYPE t_상품코드_list IS TABLE OF VARCHAR2(5);
    v_상품코드_list t_상품코드_list := t_상품코드_list();
    v_선택된상품_list t_상품코드_list := t_상품코드_list();

    TYPE t_결제수단 IS TABLE OF VARCHAR2(5);
    v_결제수단 t_결제수단 := t_결제수단('CARD', 'CASH', 'POINT', 'TRANS', 'PHONE');

    TYPE t_상품접두사 IS TABLE OF VARCHAR2(3);
    v_상품접두사 t_상품접두사 := t_상품접두사(
            'A16', 'A22', 'A35', 'A48', 'A59',
            'B07', 'B19', 'B24', 'B38', 'B51',
            'C11', 'C26', 'C33', 'C42', 'C57',
            'D05', 'D18', 'D29', 'D41', 'D63',
            'E14', 'E27', 'E36', 'E45', 'E68',
            'F03', 'F17', 'F28', 'F39', 'F52',
            'G12', 'G25', 'G34', 'G47', 'G61',
            'H09', 'H21', 'H32', 'H44', 'H56',
            'K03', 'K15', 'K26', 'K37', 'K49',
            'L08', 'L20', 'L31', 'L43', 'L55',
            'M13', 'M24', 'M35', 'M46', 'M58',
            'N06', 'N18', 'N29', 'N40', 'N52',
            'P10', 'P23', 'P34', 'P45', 'P67',
            'Q04', 'Q16', 'Q27', 'Q38', 'Q50',
            'R11', 'R22', 'R33', 'R44', 'R66',
            'S07', 'S19', 'S30', 'S41', 'S53',
            'T12', 'T24', 'T35', 'T46', 'T58',
            'U05', 'U17', 'U28', 'U39', 'U51',
            'V09', 'V21', 'V32', 'V43', 'V65',
            'W14', 'W25', 'W36', 'W47', 'W59',
            'X08', 'X20', 'X31', 'X42', 'X54',
            'Y13', 'Y24', 'Y35', 'Y46', 'Y68',
            'Z38', 'Z49', 'Z60', 'Z71', 'Z82'
                       );

    v_중복체크 BOOLEAN;
    v_상품인덱스 NUMBER;
    v_접두사 VARCHAR2(3);

BEGIN
    v_start_time := DBMS_UTILITY.GET_TIME;
    DBMS_OUTPUT.PUT_LINE('========================================');
    DBMS_OUTPUT.PUT_LINE('데이터 생성 시작: ' || TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS'));
    DBMS_OUTPUT.PUT_LINE('목표: 주문 100만건 생성');
    DBMS_OUTPUT.PUT_LINE('========================================');

    FOR i IN 1..v_일평균상품수 LOOP
            v_접두사 := v_상품접두사(MOD(i - 1, v_상품접두사.COUNT) + 1);
            v_상품코드_list.EXTEND;
            v_상품코드_list(i) := v_접두사 || LPAD(MOD(i, 100), 2, '0');
        END LOOP;

    DBMS_OUTPUT.PUT_LINE('상품코드 ' || v_상품코드_list.COUNT || '개 생성 완료 (5글자 고정)');
    DBMS_OUTPUT.PUT_LINE('접두사 종류: ' || v_상품접두사.COUNT || '개');
    DBMS_OUTPUT.PUT_LINE('샘플: ' || v_상품코드_list(1) || ', ' || v_상품코드_list(2) || ', ' || v_상품코드_list(3));
    DBMS_OUTPUT.PUT_LINE('========================================');

    FOR i IN 1..v_총주문건수 LOOP
            v_주문번호 := 주문번호_SEQ.NEXTVAL;
            v_고객번호 := TRUNC(DBMS_RANDOM.VALUE(1, 100001));
            v_주문일자 := TRUNC(SYSDATE) - TRUNC(DBMS_RANDOM.VALUE(0, 30));

            v_상품수 := CASE
                         WHEN DBMS_RANDOM.VALUE < 0.7 THEN 1
                         WHEN DBMS_RANDOM.VALUE < 0.9 THEN 2
                         WHEN DBMS_RANDOM.VALUE < 0.97 THEN 3
                         WHEN DBMS_RANDOM.VALUE < 0.99 THEN 4
                         ELSE 5
                END;

            v_결제금액 := 0;
            v_선택된상품_list.DELETE;

            FOR j IN 1..v_상품수 LOOP

                    LOOP
                        v_상품인덱스 := TRUNC(DBMS_RANDOM.VALUE(1, v_일평균상품수 + 1));
                        v_상품코드 := v_상품코드_list(v_상품인덱스);

                        v_중복체크 := FALSE;
                        IF v_선택된상품_list.COUNT > 0 THEN
                            FOR k IN 1..v_선택된상품_list.COUNT LOOP
                                    IF v_선택된상품_list(k) = v_상품코드 THEN
                                        v_중복체크 := TRUE;
                                        EXIT;
                                    END IF;
                                END LOOP;
                        END IF;

                        EXIT WHEN NOT v_중복체크;
                    END LOOP;

                    v_선택된상품_list.EXTEND;
                    v_선택된상품_list(v_선택된상품_list.COUNT) := v_상품코드;

                    v_주문가격 := TRUNC(DBMS_RANDOM.VALUE(1, 501)) * 1000;

                    v_주문수량 := CASE
                                  WHEN DBMS_RANDOM.VALUE < 0.8 THEN TRUNC(DBMS_RANDOM.VALUE(1, 4))
                                  ELSE TRUNC(DBMS_RANDOM.VALUE(4, 11))
                        END;

                    v_할인율 := CASE
                                 WHEN DBMS_RANDOM.VALUE < 0.5 THEN NULL
                                 ELSE TRUNC(DBMS_RANDOM.VALUE(5, 31))
                        END;

                    IF v_할인율 IS NULL THEN
                        v_주문금액 := v_주문가격 * v_주문수량;
                    ELSE
                        v_주문금액 := TRUNC(v_주문가격 * v_주문수량 * (100 - v_할인율) / 100);
                    END IF;

                    INSERT INTO 주문상품 (
                        주문번호, 상품코드, 주문일자, 주문시각,
                        주문가격, 주문수량, 주문금액, 할인율
                    ) VALUES (
                                 v_주문번호,
                                 v_상품코드,
                                 v_주문일자,
                                 v_주문일자 + INTERVAL '9' HOUR + DBMS_RANDOM.VALUE(0, 14) * INTERVAL '1' HOUR
                                     + DBMS_RANDOM.VALUE(0, 60) * INTERVAL '1' MINUTE,
                                 v_주문가격,
                                 v_주문수량,
                                 v_주문금액,
                                 v_할인율
                             );

                    v_결제금액 := v_결제금액 + v_주문금액;

                END LOOP;

            INSERT INTO 주문 (
                주문번호, 주문일자, 주문시각, 고객번호,
                결제금액, 결제수단코드, 배송주소
            ) VALUES (
                         v_주문번호,
                         v_주문일자,
                         v_주문일자 + INTERVAL '9' HOUR + DBMS_RANDOM.VALUE(0, 14) * INTERVAL '1' HOUR,
                         v_고객번호,
                         v_결제금액,
                         v_결제수단(TRUNC(DBMS_RANDOM.VALUE(1, 6))),
                         '서울시 ' || TRUNC(DBMS_RANDOM.VALUE(1, 26)) || '구 ' || TRUNC(DBMS_RANDOM.VALUE(1, 1000)) || '번지'
                     );

            v_commit_cnt := v_commit_cnt + 1;

            IF MOD(i, 10000) = 0 THEN
                COMMIT;
                DBMS_OUTPUT.PUT_LINE(
                        LPAD(TO_CHAR(i, '999,999,999'), 12) || '건 완료 (' ||
                        LPAD(TO_CHAR(ROUND(i / v_총주문건수 * 100, 1), '999.9'), 6) || '%) - ' ||
                        TO_CHAR(SYSDATE, 'HH24:MI:SS')
                );
                v_commit_cnt := 0;
            END IF;

        END LOOP;

    COMMIT;

    v_end_time := DBMS_UTILITY.GET_TIME;

    DBMS_OUTPUT.PUT_LINE('========================================');
    DBMS_OUTPUT.PUT_LINE('데이터 생성 완료!');
    DBMS_OUTPUT.PUT_LINE('========================================');
    DBMS_OUTPUT.PUT_LINE('총 소요시간: ' || ROUND((v_end_time - v_start_time) / 100, 2) || '초');

    DECLARE
        v_주문수 NUMBER;
        v_주문상품수 NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_주문수 FROM 주문;
        SELECT COUNT(*) INTO v_주문상품수 FROM 주문상품;

        DBMS_OUTPUT.PUT_LINE('주문 건수: ' || TO_CHAR(v_주문수, '999,999,999') || '건');
        DBMS_OUTPUT.PUT_LINE('주문상품 건수: ' || TO_CHAR(v_주문상품수, '999,999,999') || '건');
        DBMS_OUTPUT.PUT_LINE('주문당 평균 상품수: ' || ROUND(v_주문상품수 / v_주문수, 2) || '개');
        DBMS_OUTPUT.PUT_LINE('========================================');
    END;

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('오류 발생: ' || SQLERRM);
        DBMS_OUTPUT.PUT_LINE('발생 위치: ' || DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
        RAISE;
END;
/

-- 쿼리
SELECT 상품코드, SUM(주문수량) AS "총주문량", SUM(주문금액) AS "총주문금액"
FROM 주문상품
WHERE (상품코드 LIKE 'A16%' OR 상품코드 LIKE 'K03' OR 상품코드 LIKE 'Z386')
AND 주문일자 = TRUNC(SYSDATE)
GROUP BY 상품코드;

CREATE INDEX 주문상품_X1 ON 주문상품(주문일자, 상품코드);

SELECT /*+ INDEX(O 주문상품_X1) USE_CONCAT */
    상품코드, SUM(주문수량) AS "총주문량", SUM(주문금액) AS "총주문금액"
FROM 주문상품 O
WHERE (상품코드 LIKE 'A16%' OR 상품코드 LIKE 'K03' OR 상품코드 LIKE 'Z386')
  AND 주문일자 = TRUNC(SYSDATE)
GROUP BY 상품코드;

SELECT /*+ USE_CONCAT */
    상품코드, SUM(주문수량) AS "총주문량", SUM(주문금액) AS "총주문금액"
FROM 주문상품
WHERE (상품코드 LIKE 'A16%' OR 상품코드 LIKE 'K03' OR 상품코드 LIKE 'Z386')
  AND 주문일자 = TRUNC(SYSDATE)
GROUP BY 상품코드;

-- 50번
SELECT /*+ INDEX(O 주문상품_X1) */
    상품코드, SUM(주문수량) AS "총주문량", SUM(주문금액) AS "총주문금액"
FROM 주문상품 O
WHERE 주문일자 >= ADD_MONTHS(SYSDATE, -1)
AND (SUBSTR(상품코드, 1, 3) IN ('A16', 'K03')
    OR
     SUBSTR(상품코드, 1, 4) = 'Z386')
GROUP BY 상품코드;

SELECT /*+ INDEX(O 주문상품_X1) */
    상품코드, SUM(주문수량) AS "총주문량", SUM(주문금액) AS "총주문금액"
FROM 주문상품 O
WHERE 주문일자 >= ADD_MONTHS(SYSDATE, -1)
  AND (SUBSTR(상품코드, 1, 3) = 'A16' OR
       SUBSTR(상품코드, 1, 3) = 'K03' OR
       SUBSTR(상품코드, 1, 4) = 'Z386')
GROUP BY 상품코드;

SELECT /*+ INDEX(O 주문상품_X1) USE_CONCAT */
    상품코드, SUM(주문수량) AS "총주문량", SUM(주문금액) AS "총주문금액"
FROM 주문상품 O
WHERE 주문일자 >= ADD_MONTHS(SYSDATE, -1)
  AND (상품코드 LIKE 'A16%' OR
       상품코드 LIKE 'K03%' OR
       상품코드 LIKE 'Z386%')
GROUP BY 상품코드;

SELECT /*+ INDEX(O 주문상품_X1) NO_EXPAND */
    상품코드, SUM(주문수량) AS "총주문량", SUM(주문금액) AS "총주문금액"
FROM 주문상품 O
WHERE 주문일자 >= ADD_MONTHS(SYSDATE, -1)
  AND (상품코드 LIKE 'A16%' OR
       상품코드 LIKE 'K03%' OR
       상품코드 LIKE 'Z386%')
GROUP BY 상품코드;
