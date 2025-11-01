DROP TABLE IF EXISTS 작업지시 CASCADE CONSTRAINTS;
DROP TABLE IF EXISTS 개통접수 CASCADE CONSTRAINTS;
DROP TABLE IF EXISTS 장애접수 CASCADE CONSTRAINTS;

CREATE TABLE 작업지시 (
                      작업일련번호 NUMBER NOT NULL,
                      방문예정일자 DATE NOT NULL,
                      실제방문일자 DATE NULL,
                      작업구분코드 CHAR(1) NOT NULL,
                      접수번호 NUMBER NOT NULL,
                      작업자ID VARCHAR2(7) NOT NULL,
                      작업상태코드 CHAR(1) NOT NULL,
                      CONSTRAINT 작업지시_PK PRIMARY KEY (작업일련번호)
);

CREATE TABLE 개통접수 (
                      개통접수번호 NUMBER NOT NULL,
                      개통접수일시 DATE NOT NULL,
                      개통희망일자 DATE NOT NULL,
                      고객번호 NUMBER NOT NULL,
                      주소 VARCHAR2(200) NOT NULL,
                      CONSTRAINT 개통접수_PK PRIMARY KEY (개통접수번호)
);

CREATE TABLE 장애접수 (
                      장애접수번호 NUMBER NOT NULL,
                      장애접수일시 DATE NOT NULL,
                      장애발생일시 DATE NOT NULL,
                      고객번호 NUMBER NOT NULL,
                      주소 VARCHAR2(200) NOT NULL,
                      CONSTRAINT 장애접수_PK PRIMARY KEY (장애접수번호)
);

DECLARE
    v_start_date DATE := SYSDATE - 365;
    TYPE addr_array IS TABLE OF VARCHAR2(100);
    v_cities addr_array := addr_array('서울시 강남구', '서울시 서초구', '서울시 송파구', '서울시 강동구', '서울시 마포구',
                                      '경기도 수원시', '경기도 성남시', '경기도 용인시', '경기도 부천시', '경기도 안양시',
                                      '인천시 남동구', '인천시 부평구', '부산시 해운대구', '대구시 수성구', '광주시 서구');
    v_dongs addr_array := addr_array('역삼동', '삼성동', '대치동', '논현동', '청담동', '도곡동', '개포동', '일원동', '수서동', '방이동');
BEGIN
    FOR i IN 1..600000 LOOP
            INSERT INTO 개통접수 VALUES (
                                        i,
                                        v_start_date + DBMS_RANDOM.VALUE(0, 365),
                                        v_start_date + DBMS_RANDOM.VALUE(0, 365),
                                        TRUNC(DBMS_RANDOM.VALUE(1, 100000)),
                                        v_cities(TRUNC(DBMS_RANDOM.VALUE(1, 16))) || ' ' || v_dongs(TRUNC(DBMS_RANDOM.VALUE(1, 11))) || ' ' || TRUNC(DBMS_RANDOM.VALUE(1, 999)) || '-' || TRUNC(DBMS_RANDOM.VALUE(1, 99))
                                    );
            IF MOD(i, 10000) = 0 THEN COMMIT; END IF;
        END LOOP;
    COMMIT;

    FOR i IN 1..400000 LOOP
            INSERT INTO 장애접수 VALUES (
                                        i,
                                        v_start_date + DBMS_RANDOM.VALUE(0, 365),
                                        v_start_date + DBMS_RANDOM.VALUE(0, 365),
                                        TRUNC(DBMS_RANDOM.VALUE(1, 100000)),
                                        v_cities(TRUNC(DBMS_RANDOM.VALUE(1, 16))) || ' ' || v_dongs(TRUNC(DBMS_RANDOM.VALUE(1, 11))) || ' ' || TRUNC(DBMS_RANDOM.VALUE(1, 999)) || '-' || TRUNC(DBMS_RANDOM.VALUE(1, 99))
                                    );
            IF MOD(i, 10000) = 0 THEN COMMIT; END IF;
        END LOOP;
    COMMIT;

    FOR i IN 1..1000000 LOOP
            INSERT INTO 작업지시 VALUES (
                                        i,
                                        v_start_date + DBMS_RANDOM.VALUE(0, 365),
                                        CASE WHEN DBMS_RANDOM.VALUE(0, 1) > 0.3 THEN v_start_date + DBMS_RANDOM.VALUE(0, 365) ELSE NULL END,
                                        CASE WHEN DBMS_RANDOM.VALUE(0, 1) < 0.6 THEN 'A' ELSE 'B' END,
                                        TRUNC(DBMS_RANDOM.VALUE(1, CASE WHEN DBMS_RANDOM.VALUE(0, 1) < 0.6 THEN 600001 ELSE 400001 END)),
                                        CASE WHEN DBMS_RANDOM.VALUE(1, 101) = 1 THEN 'Z123456' ELSE 'W' || LPAD(TRUNC(DBMS_RANDOM.VALUE(1, 101)), 6, '0') END,
                                        CHR(65 + TRUNC(DBMS_RANDOM.VALUE(0, 3)))
                                    );
            IF MOD(i, 10000) = 0 THEN COMMIT; END IF;
        END LOOP;
    COMMIT;
END;
/

-- 54
CREATE INDEX 작업지시_X1 ON 작업지시(작업구분코드, 방문예정일자);

SELECT C.작업일련번호
     , C.작업자ID
     , '개통' AS 작업구분
     , A.고객번호
     , A.주소
FROM 작업지시 C, 개통접수 A
WHERE C.작업구분코드 = 'A'
  AND C.방문예정일자 > TRUNC(SYSDATE - 1)
  AND A.개통접수번호 = C.접수번호
UNION ALL
SELECT C.작업일련번호
     , C.작업자ID
     , '장애' AS 작업구분
     , B.고객번호
     , B.주소
FROM 작업지시 C, 장애접수 B
WHERE C.작업구분코드 = 'B'
  AND C.방문예정일자 > TRUNC(SYSDATE - 1)
  AND B.장애접수번호 = C.접수번호;

DROP INDEX 작업지시_X1;

-- 55
CREATE INDEX 작업지시_X1 ON 작업지시(방문예정일자);

SELECT C.작업일련번호
     , C.작업자ID
     , CASE C.작업구분코드 WHEN 'A' THEN '개통' ELSE '장애' END AS 작업구분
     , CASE C.작업구분코드 WHEN 'A' THEN A.고객번호 ELSE B.고객번호 END AS 고객번호
     , CASE C.작업구분코드 WHEN 'A' THEN A.주소 ELSE B.주소 END AS 주소
FROM 작업지시 C, 개통접수 A, 장애접수 B
WHERE C.방문예정일자 > TRUNC(SYSDATE - 1)
  AND A.개통접수번호(+) = CASE C.작업구분코드 WHEN 'A' THEN C.접수번호 END
  AND B.장애접수번호(+) = CASE C.작업구분코드 WHEN 'B' THEN C.접수번호 END;

DROP INDEX 작업지시_X1;

-- 56
CREATE INDEX 작업지시_X1 ON 작업지시(접수번호, 작업구분코드);
CREATE INDEX 개통접수_X1 ON 개통접수(개통접수일시);
CREATE INDEX 장애접수_X1 ON 장애접수(장애접수일시);

SELECT C.작업일련번호, C.작업자ID, '개통' AS 작업구분, A.고객번호, A.주소
FROM 개통접수 A, 작업지시 C
WHERE A.개통접수일시 >= TRUNC(SYSDATE)
  AND A.개통접수일시 < TRUNC(SYSDATE + 1)
  AND C.접수번호 = A.개통접수번호
  AND C.작업구분코드 = 'A'
UNION ALL
SELECT C.작업일련번호, C.작업자ID, '장애' AS 작업구분, B.고객번호, B.주소
FROM 장애접수 B, 작업지시 C
WHERE B.장애접수일시 >= TRUNC(SYSDATE)
  AND B.장애접수일시 < TRUNC(SYSDATE + 1)
  AND C.접수번호 = B.장애접수번호
  AND C.작업구분코드 = 'B';