drop table results;
create table results (id INT, response text);

/*1.	Вывести максимальное количество человек в одном бронировании*/

INSERT INTO results
SELECT 1 as id, max(pass) as max_pass
	FROM (SELECT count(t2.passenger_id) as pass, t1.book_ref
		FROM bookings t1
		left join tickets t2 on t1.book_ref = t2.book_ref
		group by t1.book_ref ) as t3 ;


/*2.	Вывести количество бронирований с количеством людей больше среднего значения людей на одно бронирование*/

INSERT INTO results
SELECT 2, count(t1.book_ref)
FROM (SELECT book_ref
         FROM bookings.tickets
         group by book_ref
         having count(passenger_id) > (SELECT count(passenger_id) / count(DISTINCT book_ref) * 1.0
                                          FROM bookings.tickets)) as t1;

/*3.	Вывести количество бронирований, у которых состав пассажиров повторялся два и более раза, среди бронирований с максимальным количеством людей (п.1)?*/

INSERT INTO results
SELECT 3, count(*)
FROM(
	SELECT book_ref, passenger_id, passenger_name, count(passenger_id) over (partition by book_ref) as book_count FROM bookings.tickets
	) b1
left join (
	SELECT book_ref, passenger_id, passenger_name, count(passenger_id) over (partition by book_ref) as book_count FROM bookings.tickets
	) b2 on b1.passenger_id = b2.passenger_id
WHERE b1.book_ref != b2.book_ref
and b1.book_count = b2.book_count
and b1.book_count = (SELECT count(ticket_no) as bookings FROM bookings.tickets b group by book_ref
order by count(ticket_no) desc limit 1);


/*4.	Вывести номера брони и контактную информацию по пассажирам в брони (passenger_id, passenger_name, contact_data) с количеством людей в брони = 3*/

INSERT INTO results
SELECT 4, concat_ws('|', t.book_ref, string_agg(t.passenger_info, '|'))
FROM ( SELECT book_ref
              , concat_ws('|', passenger_id, passenger_name, contact_data) AS passenger_info
         FROM bookings.tickets
         WHERE book_ref in ( SELECT book_ref
                               FROM bookings.tickets
                               group by book_ref
                               having count(passenger_id) = 3)) t
GROUP BY t.book_ref;

/*5.	Вывести максимальное количество перелётов на бронь*/

INSERT INTO results
SELECT 5, count(book_ref) a
FROM bookings t1 join tickets t2 using(book_ref)
join ticket_flights t3 using(ticket_no)
group by book_ref
order by a desc
limit 1;

/*6.	Вывести максимальное количество перелётов на пассажира в одной брони*/

INSERT INTO results
SELECT 6, count(*) c
FROM bookings b
join tickets t using(book_ref)
join ticket_flights tf using(ticket_no)
group by book_ref, passenger_id
order by c desc
limit 1;

/*7.	Вывести максимальное количество перелётов на пассажира*/

INSERT INTO results
SELECT 7, count(*) c
FROM tickets t
join ticket_flights tf using(ticket_no)
group by passenger_id
order by c desc
limit 1;

/*8.	Вывести контактную информацию по пассажиру(ам) (passenger_id, passenger_name, contact_data) и общие траты на билеты, для пассажира потратившему минимальное количество денег на перелеты*/

INSERT INTO results
SELECT 8, concat(q.passenger_id, '|', q.passenger_name, '|', q.email, '|', q.phone, '|', q.sum_flights)
FROM
	( SELECT a.passenger_id
		  ,a.passenger_name
		  ,cast(a.contact_data::json->'email' as text) as email
	  ,cast(a.contact_data::json->'phone' as text) as phone
	  ,sum(b.amount) as sum_flights
	FROM bookings.tickets a
		join bookings.ticket_flights b
			on a.ticket_no = b.ticket_no
	group by a.passenger_id, a.passenger_name, a.contact_data
	having sum(b.amount) = (SELECT min(f.summa)
							FROM (SELECT sum(b.amount) as summa
								FROM bookings.tickets a
									join bookings.ticket_flights b
										on a.ticket_no = b.ticket_no
								group by a.passenger_id) as f)
	order by a.passenger_id, a.passenger_name, email, phone) as q;

/*9.	Вывести контактную информацию по пассажиру(ам) (passenger_id, passenger_name, contact_data) и общее время в полётах, для пассажира, который провёл максимальное время в полётах*/

INSERT INTO results
SELECT 9, concat(passenger_id, '|', passenger_name, '|', contact_data, '|', sum_duration)
FROM
	(SELECT passenger_id, passenger_name, contact_data, sum(actual_duration) sum_duration,
	rank() over(order by sum(actual_duration) desc) rank_sum_duration
	FROM tickets t1
	join ticket_flights using(ticket_no)
	join flights_v using(flight_id)
	WHERE actual_duration is not null
	group by ticket_no) t2
WHERE rank_sum_duration = 1
order by passenger_id, passenger_name, contact_data;

/*10.	Вывести город(а) с количеством аэропортов больше одного*/

INSERT INTO results
SELECT 10, city
FROM airports
group by city
having count(city) > 1
order by city;

/*11.	Вывести город(а), у которого самое меньшее количество городов прямого сообщения*/

INSERT INTO results
SELECT 11, a.city
FROM bookings.flights f
	left join bookings.airports a
		on f.departure_airport = a.airport_code
group by a.city
having count(distinct f.arrival_airport) = (SELECT min(a.count) FROM
											(SELECT departure_airport, count(distinct arrival_airport) as count
											FROM bookings.flights
											group by departure_airport) as a)
order by city;

/*12.	Вывести пары городов, у которых нет прямых сообщений исключив реверсные дубликаты*/

INSERT INTO results
SELECT 12, concat(f.airoport_dep, '|', f.airoport_arr)
FROM
	(
	SELECT z.airoport_dep
		  ,z.airoport_arr
	FROM
		(
		SELECT a.city as airoport_dep, b.city as airoport_arr
		FROM bookings.airports a
			cross join bookings.airports b
		except
		SELECT distinct departure_city, arrival_city
		FROM bookings.flights_v
		) as z
	WHERE z.airoport_dep <= z.airoport_arr
	union
	SELECT z.airoport_arr
		  ,z.airoport_arr
	FROM
		(
		SELECT a.city as airoport_dep, b.city as airoport_arr
		FROM bookings.airports a
			cross join bookings.airports b
		except
		SELECT distinct departure_city, arrival_city
		FROM bookings.flights_v
		) as z
	WHERE z.airoport_dep > z.airoport_arr
	) as f
WHERE f.airoport_dep != f.airoport_arr
order by f.airoport_dep, f.airoport_arr;

/*13.	Вывести города, до которых нельзя добраться без пересадок из Москвы?*/

INSERT INTO results
SELECT distinct 13, departure_city
FROM routes
WHERE departure_city != 'Москва'
	and departure_city not in (
		SELECT arrival_city FROM routes
		WHERE departure_city = 'Москва');

/*14.	Вывести модель самолета, который выполнил больше всего рейсов*/

INSERT INTO results
SELECT 14, a.model
FROM bookings.flights f
	left join bookings.aircrafts a
		on f.aircraft_code = a.aircraft_code
WHERE f.status = 'Arrived'
	or f.status = 'Departed'
group by a.model
order by count(*) desc
limit 1;

/*15.	Вывести модель самолета, который перевез больше всего пассажиров*/

INSERT INTO results
SELECT 15, a.model
FROM bookings.flights f
	left join bookings.aircrafts a
		on f.aircraft_code = a.aircraft_code
	right join bookings.ticket_flights tf
		on f.flight_id = tf.flight_id
	left join bookings.tickets t
		on t.ticket_no = tf.ticket_no
WHERE f.status = 'Arrived'
	or f.status = 'Departed'
group by a.model
order by count(t.passenger_id) desc
limit 1;

/*16.	Вывести отклонение в минутах суммы запланированного времени перелета от фактического по всем перелётам*/

INSERT INTO results
SELECT 16, cast(extract(epoch FROM sum((actual_arrival - actual_departure) - (scheduled_arrival - scheduled_departure)))/60 as int)
FROM bookings.flights
WHERE actual_arrival is not null;

/*17.	Вывести города, в которые осуществлялся перелёт из Санкт-Петербурга 2017-08-11*/

INSERT INTO results
SELECT distinct 17,
	arrival_city as response
FROM flights_v f
WHERE departure_city = 'Санкт-Петербург'
and date_trunc('day',actual_departure_local) = '2017-08-11'
order by 1,2;

/*18.	Вывести перелёт(ы) с максимальной стоимостью всех билетов*/

INSERT INTO results
SELECT 18, f.flight_id
FROM bookings.flights f
	inner join bookings.ticket_flights tf
		on f.flight_id = tf.flight_id
group by f.flight_id
having sum(tf.amount) =
					(SELECT max(summa)
					FROM
						(
						SELECT sum(tf.amount) as summa
						FROM bookings.flights f
							inner join bookings.ticket_flights tf
								on f.flight_id = tf.flight_id
						group by f.flight_id
						) as f);


/*19.	Выбрать дни в которых было осуществлено минимальное количество перелётов*/

INSERT INTO results
SELECT 19, date_departure
FROM
	(SELECT actual_departure::date date_departure, count(flight_id) count_flight,
	min(count(flight_id)) over() min_count_flight
	FROM flights f
	WHERE actual_departure is not null
	group by actual_departure::date) t
WHERE count_flight = min_count_flight
order by date_departure;


/*20.	Вывести среднее количество вылетов в день из Москвы за 08 месяц 2017 года*/

INSERT INTO results
SELECT 20, avg(fl_cnt) FROM
(
	SELECT to_char(coalesce(actual_departure_local , scheduled_departure_local), 'YYYY-MM-dd') as dt, count(flight_id) as fl_cnt FROM bookings.flights_v f
	WHERE to_char(coalesce(actual_departure_local , scheduled_departure_local), 'YYYY-MM') = '2017-08'
	and departure_city = 'Москва'
	and status in ('Departed','Arrived')
	group by to_char(coalesce(actual_departure_local , scheduled_departure_local), 'YYYY-MM-dd')) t1;

/*21.	Вывести топ 5 городов у которых среднее время перелета до пункта назначения больше 3 часов*/

INSERT INTO results
SELECT 21, t1.departure_city FROM
(SELECT departure_city,
		   extract (epoch FROM avg(actual_duration))/60/60 as avg_dur,
		   count(flight_id) as cnt_flights
	FROM flights_v
	WHERE status = 'Arrived'
	group by departure_city
	having extract (epoch FROM avg(actual_duration))/60/60 > 3
	order by 3 desc
	limit 5) t1;