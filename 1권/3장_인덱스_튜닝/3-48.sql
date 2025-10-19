DROP TABLE IF EXISTS 거래 CASCADE CONSTRAINTS;
-- DDL: 테이블 생성
CREATE TABLE 거래 (
                    증서번호 VARCHAR2(20) NOT NULL,
                    이체사유발생일자 DATE NOT NULL,
                    거래코드 VARCHAR2(10) NOT NULL,
                    순번 NUMBER NOT NULL,
                    투입인출구분코드 CHAR(1) NOT NULL,
                    기본이체금액 NUMBER DEFAULT 0,
                    정산이자 NUMBER DEFAULT 0,
                    CONSTRAINT PK_거래 PRIMARY KEY (증서번호, 이체사유발생일자, 거래코드, 순번)
);

-- A-Rows 수에 맞춰 데이터 삽입
DECLARE
    v_증서번호 VARCHAR2(20) := 'CERT-2024-001';
    v_기준일자 DATE := TO_DATE('2024-01-01', 'YYYY-MM-DD');
    v_cnt NUMBER := 0;

    TYPE t_거래코드 IS TABLE OF VARCHAR2(10);
    v_허용거래코드 t_거래코드 := t_거래코드('7401', '7402', '7501', '7502', '7505', '7506');
    v_제외거래코드 t_거래코드 := t_거래코드('7411', '7412', '7503', '7504');

BEGIN
    DBMS_OUTPUT.PUT_LINE('데이터 삽입 시작...');

    -- 1. 투입인출구분코드 'G' 데이터 1600건 삽입
    -- INDEX RANGE SCAN으로 3400건을 스캔하지만, 조건에 맞는 건수는 1600건
    FOR i IN 1..1600 LOOP
            INSERT INTO 거래 (
                증서번호,
                이체사유발생일자,
                거래코드,
                순번,
                투입인출구분코드,
                기본이체금액,
                정산이자
            ) VALUES (
                         v_증서번호,
                         v_기준일자 - MOD(i, 10), -- 날짜 분산
                         v_허용거래코드(MOD(i, 6) + 1), -- 허용된 거래코드 순환
                         i,
                         'G',
                         ROUND(DBMS_RANDOM.VALUE(100000, 5000000), -3), -- 랜덤 금액
                         ROUND(DBMS_RANDOM.VALUE(5000, 250000), -3) -- 랜덤 이자
                     );

            v_cnt := v_cnt + 1;

            IF MOD(v_cnt, 500) = 0 THEN
                COMMIT;
                DBMS_OUTPUT.PUT_LINE('진행중... ' || v_cnt || '건 삽입');
            END IF;
        END LOOP;

    -- 2. 투입인출구분코드 'S' 데이터 1800건 삽입
    -- INDEX RANGE SCAN으로 3400건을 스캔하지만, 조건에 맞는 건수는 1800건
    FOR i IN 1..1800 LOOP
            INSERT INTO 거래 (
                증서번호,
                이체사유발생일자,
                거래코드,
                순번,
                투입인출구분코드,
                기본이체금액,
                정산이자
            ) VALUES (
                         v_증서번호,
                         v_기준일자 - MOD(i, 15), -- 날짜 분산
                         v_허용거래코드(MOD(i, 6) + 1), -- 허용된 거래코드 순환
                         i + 10000, -- 순번이 겹치지 않도록
                         'S',
                         ROUND(DBMS_RANDOM.VALUE(100000, 5000000), -3),
                         ROUND(DBMS_RANDOM.VALUE(5000, 250000), -3)
                     );

            v_cnt := v_cnt + 1;

            IF MOD(v_cnt, 500) = 0 THEN
                COMMIT;
                DBMS_OUTPUT.PUT_LINE('진행중... ' || v_cnt || '건 삽입');
            END IF;
        END LOOP;

    -- 3. 제외 거래코드 데이터 추가 (INDEX RANGE SCAN 3400건을 만들기 위한 노이즈 데이터)
    -- 'G'용 추가 데이터: 3400 - 1600 = 1800건
    FOR i IN 1..900 LOOP
            INSERT INTO 거래 (
                증서번호,
                이체사유발생일자,
                거래코드,
                순번,
                투입인출구분코드,
                기본이체금액,
                정산이자
            ) VALUES (
                         v_증서번호,
                         v_기준일자 - MOD(i, 20),
                         v_제외거래코드(MOD(i, 4) + 1), -- 제외될 거래코드
                         i + 20000,
                         'G',
                         ROUND(DBMS_RANDOM.VALUE(100000, 3000000), -3),
                         ROUND(DBMS_RANDOM.VALUE(5000, 150000), -3)
                     );

            v_cnt := v_cnt + 1;
        END LOOP;

    -- 'S'용 추가 데이터: 3400 - 1800 = 1600건
    FOR i IN 1..800 LOOP
            INSERT INTO 거래 (
                증서번호,
                이체사유발생일자,
                거래코드,
                순번,
                투입인출구분코드,
                기본이체금액,
                정산이자
            ) VALUES (
                         v_증서번호,
                         v_기준일자 - MOD(i, 20),
                         v_제외거래코드(MOD(i, 4) + 1), -- 제외될 거래코드
                         i + 30000,
                         'S',
                         ROUND(DBMS_RANDOM.VALUE(100000, 3000000), -3),
                         ROUND(DBMS_RANDOM.VALUE(5000, 150000), -3)
                     );

            v_cnt := v_cnt + 1;
        END LOOP;

    COMMIT;

    DBMS_OUTPUT.PUT_LINE('========================================');
    DBMS_OUTPUT.PUT_LINE('데이터 삽입 완료: 총 ' || v_cnt || '건');
    DBMS_OUTPUT.PUT_LINE('========================================');

    -- 데이터 검증
    DECLARE
        v_g_count NUMBER;
        v_s_count NUMBER;
        v_g_excluded NUMBER;
        v_s_excluded NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_g_count
        FROM 거래
        WHERE 증서번호 = v_증서번호
          AND 이체사유발생일자 <= SYSDATE
          AND 거래코드 NOT IN ('7411','7412','7503','7504')
          AND 투입인출구분코드 = 'G';

        SELECT COUNT(*) INTO v_s_count
        FROM 거래
        WHERE 증서번호 = v_증서번호
          AND 이체사유발생일자 <= SYSDATE
          AND 거래코드 NOT IN ('7411','7412','7503','7504')
          AND 투입인출구분코드 = 'S';

        SELECT COUNT(*) INTO v_g_excluded
        FROM 거래
        WHERE 증서번호 = v_증서번호
          AND 투입인출구분코드 = 'G';

        SELECT COUNT(*) INTO v_s_excluded
        FROM 거래
        WHERE 증서번호 = v_증서번호
          AND 투입인출구분코드 = 'S';

        DBMS_OUTPUT.PUT_LINE('투입(G) - 조건 충족: ' || v_g_count || '건 (목표: 1600건)');
        DBMS_OUTPUT.PUT_LINE('투입(G) - 전체 스캔: ' || v_g_excluded || '건 (목표: ~3400건)');
        DBMS_OUTPUT.PUT_LINE('출금(S) - 조건 충족: ' || v_s_count || '건 (목표: 1800건)');
        DBMS_OUTPUT.PUT_LINE('출금(S) - 전체 스캔: ' || v_s_excluded || '건 (목표: ~3400건)');
    END;

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('오류 발생: ' || SQLERRM);
        RAISE;
END;
/

----
SELECT NVL((A.기본이체금액+A.정산이자) - (B.기본이체금액+B.정산이자), 0)
FROM (
         SELECT NVL(SUM(기본이체금액), 0) 기본이체금액
              , NVL(SUM(정산이자), 0) 정산이자
         FROM 거래
         WHERE 증서번호 = 'CERT-2024-001'
           AND 이체사유발생일자 <= SYSDATE
           AND 거래코드 NOT IN ('7411','7412','7503','7504')
           AND 투입인출구분코드 = 'G'
     ) A, (
         SELECT NVL(SUM(기본이체금액), 0) 기본이체금액
              , NVL(SUM(정산이자), 0) 정산이자
         FROM 거래
         WHERE 증서번호 = 'CERT-2024-001'
           AND 이체사유발생일자 <= SYSDATE
           AND 거래코드 NOT IN ('7411','7412','7503','7504')
           AND 투입인출구분코드 = 'S'
     ) B;

--- 1. 인덱스
CREATE INDEX 거래_X1 ON 거래(증서번호, 투입인출구분코드, 이체사유발생일자);
DROP INDEX 거래_X1;
CREATE INDEX 거래_X2 ON 거래(증서번호, 투입인출구분코드, 이체사유발생일자, 거래코드);
DROP INDEX 거래_X2;

SELECT NVL((A.기본이체금액+A.정산이자) - (B.기본이체금액+B.정산이자), 0)
FROM (
         SELECT NVL(SUM(기본이체금액), 0) 기본이체금액
              , NVL(SUM(정산이자), 0) 정산이자
         FROM 거래
         WHERE 증서번호 = 'CERT-2024-001'
           AND 이체사유발생일자 <= SYSDATE
           AND 거래코드 NOT IN ('7411','7412','7503','7504')
           AND 투입인출구분코드 = 'G'
     ) A, (
         SELECT NVL(SUM(기본이체금액), 0) 기본이체금액
              , NVL(SUM(정산이자), 0) 정산이자
         FROM 거래
         WHERE 증서번호 = 'CERT-2024-001'
           AND 이체사유발생일자 <= SYSDATE
           AND 거래코드 NOT IN ('7411','7412','7503','7504')
           AND 투입인출구분코드 = 'S'
     ) B;

--- 2. 쿼리 수정
SELECT (G_기본이체금액 + G_정산이자) - (S_기본이체금액 + S_정산이자)
FROM (
         SELECT NVL(SUM(CASE WHEN 투입인출구분코드 = 'G' THEN 기본이체금액 END), 0) G_기본이체금액
              , NVL(SUM(CASE WHEN 투입인출구분코드 = 'G' THEN 정산이자 END), 0) G_정산이자
              , NVL(SUM(CASE WHEN 투입인출구분코드 = 'S' THEN 기본이체금액 END), 0) S_기본이체금액
              , NVL(SUM(CASE WHEN 투입인출구분코드 = 'S' THEN 정산이자 END), 0) S_정산이자
         FROM 거래
         WHERE 증서번호 = 'CERT-2024-001'
           AND 이체사유발생일자 <= SYSDATE
           AND 거래코드 NOT IN ('7411', '7412', '7503', '7504')
           AND 투입인출구분코드 IN ('G', 'S')
     );

-- 튜닝 버전 1: WITH 절 사용 (가장 권장)
WITH 거래_필터 AS (
    SELECT
        투입인출구분코드,
        SUM(기본이체금액) AS 기본이체금액,
        SUM(정산이자) AS 정산이자
    FROM 거래
    WHERE 증서번호 = 'CERT-2024-001'
      AND 이체사유발생일자 <= SYSDATE
      AND 거래코드 NOT IN ('7411', '7412', '7503', '7504')
      AND 투입인출구분코드 IN ('G', 'S')
    GROUP BY 투입인출구분코드
)
SELECT NVL(
    (NVL(MAX(CASE WHEN 투입인출구분코드 = 'G' THEN 기본이체금액 + 정산이자 END), 0) -
    NVL(MAX(CASE WHEN 투입인출구분코드 = 'S' THEN 기본이체금액 + 정산이자 END), 0)),0) AS 차액
FROM 거래_필터;


-- 튜닝 버전 2: 단일 쿼리로 변환 (더 간단)
SELECT NVL(
   SUM(CASE WHEN 투입인출구분코드 = 'G' THEN 기본이체금액 + 정산이자 ELSE 0 END) -
    SUM(CASE WHEN 투입인출구분코드 = 'S' THEN 기본이체금액 + 정산이자 ELSE 0 END),
               0) AS 차액
FROM 거래
WHERE 증서번호 = 'CERT-2024-001'
  AND 이체사유발생일자 <= SYSDATE
  AND 거래코드 NOT IN ('7411', '7412', '7503', '7504')
  AND 투입인출구분코드 IN ('G', 'S');


-- 튜닝 버전 3: PIVOT 사용 (Oracle 11g 이상)
SELECT NVL(NVL(G, 0) - NVL(S, 0), 0) AS 차액
FROM (
    SELECT
        투입인출구분코드,
        SUM(기본이체금액 + 정산이자) AS 합계
    FROM 거래
    WHERE 증서번호 = 'CERT-2024-001'
      AND 이체사유발생일자 <= SYSDATE
      AND 거래코드 NOT IN ('7411', '7412', '7503', '7504')
      AND 투입인출구분코드 IN ('G', 'S')
    GROUP BY 투입인출구분코드
)
    PIVOT (
    MAX(합계)
    FOR 투입인출구분코드 IN ('G' AS G, 'S' AS S)
    );