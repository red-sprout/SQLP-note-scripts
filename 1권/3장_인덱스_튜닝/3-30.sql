DROP TABLE IF EXISTS 일별지수업종별거래 CASCADE CONSTRAINTS;

CREATE TABLE 일별지수업종별거래 (
    지수구분코드 VARCHAR2(1),
    지수업종코드 VARCHAR2(3),
    거래명 VARCHAR2(20),
    지수종가 NUMBER,
    누적거래량 NUMBER,
    거래일자 DATE
);

CREATE INDEX 일별지수업종별거래_PK ON 일별지수업종별거래(지수구분코드, 지수업종코드, 거래일자);
CREATE INDEX 일별지수업종별거래_X1 ON 일별지수업종별거래(거래일자);

---

TRUNCATE TABLE 일별지수업종별거래;

DECLARE
    v_거래일자 DATE;
    v_지수구분코드 VARCHAR2(1);
    v_지수업종코드 VARCHAR2(3);
    v_거래명 VARCHAR2(20);
BEGIN
    -- 2025년 1월 1일부터 90일치 데이터 생성
    FOR i IN 0..89 LOOP
            v_거래일자 := TO_DATE('20250101', 'YYYYMMDD') + i;

            -- KOSPI200 (지수구분코드='1', 지수업종코드='001')
            INSERT INTO 일별지수업종별거래 (
                지수구분코드, 지수업종코드, 거래명,
                지수종가, 누적거래량, 거래일자
            ) VALUES (
                         '1', '001', 'KOSPI200',
                         2500 + DBMS_RANDOM.VALUE(-100, 100),
                         TRUNC(DBMS_RANDOM.VALUE(1000000, 5000000)),
                         v_거래일자
                     );

            -- KOSDAQ (지수구분코드='2', 지수업종코드='003')
            INSERT INTO 일별지수업종별거래 (
                지수구분코드, 지수업종코드, 거래명,
                지수종가, 누적거래량, 거래일자
            ) VALUES (
                         '2', '003', 'KOSDAQ',
                         800 + DBMS_RANDOM.VALUE(-50, 50),
                         TRUNC(DBMS_RANDOM.VALUE(500000, 3000000)),
                         v_거래일자
                     );

            -- 기타 지수들 (조회 대상 아님)
            INSERT INTO 일별지수업종별거래 (
                지수구분코드, 지수업종코드, 거래명,
                지수종가, 누적거래량, 거래일자
            ) VALUES (
                         '1', '002', 'KOSPI100',
                         1500 + DBMS_RANDOM.VALUE(-50, 50),
                         TRUNC(DBMS_RANDOM.VALUE(500000, 2000000)),
                         v_거래일자
                     );

            INSERT INTO 일별지수업종별거래 (
                지수구분코드, 지수업종코드, 거래명,
                지수종가, 누적거래량, 거래일자
            ) VALUES (
                         '3', '005', '기타지수',
                         1000 + DBMS_RANDOM.VALUE(-30, 30),
                         TRUNC(DBMS_RANDOM.VALUE(300000, 1000000)),
                         v_거래일자
                     );
        END LOOP;

    COMMIT;
END;
/

BEGIN
    DBMS_STATS.GATHER_TABLE_STATS(USER, '일별지수업종별거래');
END;
/

---

SELECT 거래일자
     , SUM(DECODE(지수구분코드, '1', 지수종가, 0)) KOSPI200_IDX
     , SUM(DECODE(지수구분코드, '1', 누적거래량, 0)) KOSP1200_IDX_TRDVOL
     , SUM(DECODE(지수구분코드, '2', 지수종가, 0)) KOSDAQ_IDX
     , SUM(DECODE(지수구분코드, '2', 누적거래량, 0)) KOSDAQ_IDX_TRDVOL
FROM 일별지수업종별거래
WHERE 거래일자 BETWEEN TO_DATE('20250101', 'YYYYMMDD') AND TO_DATE('20250131', 'YYYYMMDD')
AND 지수구분코드 || 지수업종코드 IN ('1001', '2003')
GROUP BY 거래일자;

SELECT 거래일자
     , SUM(DECODE(지수구분코드, '1', 지수종가, 0)) KOSPI200_IDX
     , SUM(DECODE(지수구분코드, '1', 누적거래량, 0)) KOSP1200_IDX_TRDVOL
     , SUM(DECODE(지수구분코드, '2', 지수종가, 0)) KOSDAQ_IDX
     , SUM(DECODE(지수구분코드, '2', 누적거래량, 0)) KOSDAQ_IDX_TRDVOL
FROM 일별지수업종별거래
WHERE 거래일자 BETWEEN TO_DATE('20250101', 'YYYYMMDD') AND TO_DATE('20250131', 'YYYYMMDD')
  AND (지수구분코드, 지수업종코드) IN (('1', '001'), ('2', '003'))
GROUP BY 거래일자;