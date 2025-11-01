DROP TABLE IF EXISTS 작업지시 CASCADE CONSTRAINTS;
DROP TABLE IF EXISTS 개통접수 CASCADE CONSTRAINTS;
DROP TABLE IF EXISTS 장애접수 CASCADE CONSTRAINTS;

CREATE TABLE 작업지시 (
                      작업일련번호 NUMBER NOT NULL,
                      방문예정일자 DATE NOT NULL,
                      실제방문일자 DATE NULL,
                      개통접수번호 NUMBER NULL,
                      장애접수번호 NUMBER NULL,
                      작업자ID VARCHAR2(7) NOT NULL,
                      작업상태코드 CHAR(1) NOT NULL,
                      CONSTRAINT 작업지시_PK PRIMARY KEY (작업일련번호),
                      CONSTRAINT 작업지시_CHK CHECK (
                          (개통접수번호 IS NOT NULL AND 장애접수번호 IS NULL) OR
                          (개통접수번호 IS NULL AND 장애접수번호 IS NOT NULL)
                          )
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
    v_end_date DATE := SYSDATE;
    v_random_date DATE;
    v_random_num NUMBER;
    v_worker_id VARCHAR2(7);
    v_address VARCHAR2(200);
    v_status CHAR(1);
    v_type NUMBER;

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

            IF MOD(i, 10000) = 0 THEN
                COMMIT;
            END IF;
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

            IF MOD(i, 10000) = 0 THEN
                COMMIT;
            END IF;
        END LOOP;
    COMMIT;

    FOR i IN 1..1000000 LOOP
            v_random_num := TRUNC(DBMS_RANDOM.VALUE(1, 101));
            IF v_random_num = 1 THEN
                v_worker_id := 'Z123456';
            ELSE
                v_worker_id := 'W' || LPAD(v_random_num, 6, '0');
            END IF;

            v_status := CASE TRUNC(DBMS_RANDOM.VALUE(1, 3))
                            WHEN 1 THEN 'A'
                            WHEN 2 THEN 'B'
                END;

            v_random_date := v_start_date + DBMS_RANDOM.VALUE(0, 365);

            v_type := TRUNC(DBMS_RANDOM.VALUE(0, 2));

            IF v_type = 0 THEN
                INSERT INTO 작업지시 VALUES (
                                            i,
                                            v_random_date,
                                            CASE WHEN DBMS_RANDOM.VALUE(0, 1) > 0.3 THEN v_random_date + DBMS_RANDOM.VALUE(0, 5) ELSE NULL END,
                                            TRUNC(DBMS_RANDOM.VALUE(1, 600001)),
                                            NULL,
                                            v_worker_id,
                                            v_status
                                        );
            ELSE
                INSERT INTO 작업지시 VALUES (
                                            i,
                                            v_random_date,
                                            CASE WHEN DBMS_RANDOM.VALUE(0, 1) > 0.3 THEN v_random_date + DBMS_RANDOM.VALUE(0, 5) ELSE NULL END,
                                            NULL,
                                            TRUNC(DBMS_RANDOM.VALUE(1, 400001)),
                                            v_worker_id,
                                            v_status
                                        );
            END IF;

            IF MOD(i, 10000) = 0 THEN
                COMMIT;
            END IF;
        END LOOP;
    COMMIT;

    DBMS_OUTPUT.PUT_LINE('Complete');
END;
/

CREATE INDEX 작업지시_X1 ON 작업지시(작업자ID, 실제방문일자);

SELECT *
FROM (
         SELECT /*+ ORDERED USE_NL(B) USE_NL(C) */
             A.작업일련번호
              , A.실제방문일자
              , NVL2(A.개통접수번호, '개통', '장애') AS 접수구분
              , NVL2(A.개통접수번호, B.고객번호, C.고객번호) AS 고객번호
              , NVL2(A.개통접수번호, B.주소, C.주소) AS 주소
         FROM 작업지시 A, 개통접수 B, 장애접수 C
         WHERE A.작업자ID = 'Z123456'
           AND A.실제방문일자 >= TRUNC(ADD_MONTHS(SYSDATE, -1))
           AND B.개통접수번호(+) = A.개통접수번호
           AND C.장애접수번호(+) = A.장애접수번호
         ORDER BY A.실제방문일자 DESC
     )
WHERE ROWNUM <= 10;