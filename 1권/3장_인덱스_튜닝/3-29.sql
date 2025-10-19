DROP TABLE IF EXISTS 계좌원장 CASCADE CONSTRAINTS;
DROP TABLE IF EXISTS 월별계좌상태 CASCADE CONSTRAINTS;

CREATE TABLE 월별계좌상태 (
    계좌번호 VARCHAR2(20),
    계좌일련번호 VARCHAR2(20),
    기준연월 VARCHAR2(6),
    상태구분코드 VARCHAR2(3)
);

CREATE TABLE 계좌원장 (
    계좌번호 VARCHAR2(20),
    계좌일련번호 VARCHAR2(20),
    개설일자 DATE
);

CREATE INDEX 월말계좌상태_PK ON 월별계좌상태(계좌번호, 계좌일련번호, 기준연월);
CREATE INDEX 월말계좌상태_X1 ON 월별계좌상태(기준연월, 상태구분코드);
CREATE INDEX 계좌원장_PK ON 계좌원장(계좌번호, 계좌일련번호, 개설일자);

---

-- 기존 데이터 삭제
TRUNCATE TABLE 월별계좌상태;
TRUNCATE TABLE 계좌원장;

-- 테스트 데이터 생성
DECLARE
    v_계좌번호 VARCHAR2(20);
    v_계좌일련번호 VARCHAR2(20);
BEGIN
    -- 계좌원장: 2025년 1월 개설 계좌 100건
    FOR i IN 1..100 LOOP
            v_계좌번호 := 'ACC' || LPAD(i, 10, '0');
            v_계좌일련번호 := LPAD(i, 10, '0');

            INSERT INTO 계좌원장 (계좌번호, 계좌일련번호, 개설일자)
            VALUES (v_계좌번호, v_계좌일련번호, TO_DATE('20250101', 'YYYYMMDD') + MOD(i, 31));
        END LOOP;

    -- 계좌원장: 다른 월 개설 계좌 200건
    FOR i IN 101..300 LOOP
            v_계좌번호 := 'ACC' || LPAD(i, 10, '0');
            v_계좌일련번호 := LPAD(i, 10, '0');

            INSERT INTO 계좌원장 (계좌번호, 계좌일련번호, 개설일자)
            VALUES (v_계좌번호, v_계좌일련번호, TO_DATE('20241201', 'YYYYMMDD') + MOD(i, 60));
        END LOOP;

    -- 월별계좌상태: 2025년 6월 데이터 300건
    FOR i IN 1..300 LOOP
            v_계좌번호 := 'ACC' || LPAD(i, 10, '0');
            v_계좌일련번호 := LPAD(i, 10, '0');

            INSERT INTO 월별계좌상태 (계좌번호, 계좌일련번호, 기준연월, 상태구분코드)
            VALUES (
                       v_계좌번호,
                       v_계좌일련번호,
                       '202506',
                       CASE MOD(i, 5)
                           WHEN 0 THEN '01'
                           WHEN 1 THEN '02'
                           WHEN 2 THEN '03'
                           WHEN 3 THEN '04'
                           ELSE '05'
                           END
                   );
        END LOOP;

    COMMIT;
END;
/

-- 데이터 확인 쿼리들
SELECT '계좌원장 샘플' as 구분, a.* FROM 계좌원장 a WHERE ROWNUM <= 5;
SELECT '월말계좌상태 샘플' as 구분, a.* FROM 월별계좌상태 a WHERE ROWNUM <= 5;

-- UPDATE 실행 전 대상 건수 확인
SELECT COUNT(*) as "UPDATE 대상 건수"
FROM 월별계좌상태
WHERE 상태구분코드 <> '01'
  AND 기준연월 = '202506'
  AND 계좌번호 || 계좌일련번호 IN (
    SELECT 계좌번호 || 계좌일련번호
    FROM 계좌원장
    WHERE 개설일자 >= TO_DATE('20250101', 'YYYYMMDD')
      AND 개설일자 < TO_DATE('20250201', 'YYYYMMDD')
);

---

UPDATE 월별계좌상태 SET 상태구분코드 = '07'
WHERE 상태구분코드 <> '01'
AND 기준연월 = '202506'
AND 계좌번호 || 계좌일련번호 IN (
    SELECT 계좌번호 || 계좌일련번호
    FROM 계좌원장
    WHERE 개설일자 LIKE '202501' || '%'
);

UPDATE 월별계좌상태 SET 상태구분코드 = '07'
WHERE 상태구분코드 <> '01'
  AND 기준연월 = '202506'
  AND (계좌번호, 계좌일련번호) IN (
    SELECT 계좌번호, 계좌일련번호
    FROM 계좌원장
    WHERE 개설일자 LIKE '202501' || '%');
