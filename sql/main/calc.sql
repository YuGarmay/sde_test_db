drop table results;
create table results (id INT, response text);

/*1.	Вывести максимальное количество человек в одном бронировании*/

INSERT INTO results
SELECT 1, count(book_ref) a
FROM tickets
group by book_ref
order by a desc
limit 1;

/*2.	Вывести количество бронирований с количеством людей больше среднего значения людей на одно бронирование*/

INSERT INTO results
SELECT 2, count(t1.book_ref)
FROM (SELECT book_ref
         FROM bookings.tickets
         GROUP BY book_ref
         HAVING COUNT(passenger_id) > (SELECT COUNT(passenger_id) / COUNT(DISTINCT book_ref) * 1.0
                                          FROM bookings.tickets)) as t1;

/*3.	Вывести количество бронирований, у которых состав пассажиров повторялся два и более раза, среди бронирований с максимальным количеством людей (п.1)?*/

INSERT INTO results
select 3, count(*)
from(
	select book_ref, passenger_id, passenger_name, count(passenger_id) over (partition by book_ref) as book_count from bookings.tickets
	) b1
left join (
	select book_ref, passenger_id, passenger_name, count(passenger_id) over (partition by book_ref) as book_count from bookings.tickets
	) b2 on b1.passenger_id = b2.passenger_id
where b1.book_ref != b2.book_ref
and b1.book_count = b2.book_count
and b1.book_count = (select count(ticket_no) as bookings from bookings.tickets b group by book_ref
order by count(ticket_no) desc limit 1);


/*4.	Вывести номера брони и контактную информацию по пассажирам в брони (passenger_id, passenger_name, contact_data) с количеством людей в брони = 3*/

INSERT INTO results
SELECT 4, concat_ws('|', t.book_ref, string_agg(t.passenger_info, '|'))
FROM (
         SELECT book_ref
              , concat_ws('|', passenger_id, passenger_name, contact_data) AS passenger_info
         FROM bookings.tickets
         WHERE book_ref IN (
                               SELECT book_ref
                               FROM bookings.tickets
                               GROUP BY book_ref
                               HAVING count(passenger_id) = 3
                           )
     ) t
GROUP BY t.book_ref;

/*5.	Вывести максимальное количество перелётов на бронь*/

INSERT INTO results
select 5, count(book_ref) c
from bookings b
join tickets t using(book_ref)
join ticket_flights tf using(ticket_no)
group by book_ref
order by c desc
limit 1;

/*6.	Вывести максимальное количество перелётов на пассажира в одной брони*/

INSERT INTO results
select 6, count(*) c
from bookings b
join tickets t using(book_ref)
join ticket_flights tf using(ticket_no)
group by book_ref, passenger_id
order by c desc
limit 1;

/*7.	Вывести максимальное количество перелётов на пассажира*/

INSERT INTO results
select 7, count(*) c
from tickets t
join ticket_flights tf using(ticket_no)
group by passenger_id
order by c desc
limit 1;

/*8.	Вывести контактную информацию по пассажиру(ам) (passenger_id, passenger_name, contact_data) и общие траты на билеты, для пассажира потратившему минимальное количество денег на перелеты*/

INSERT INTO results
select 8, concat(q.passenger_id, '|', q.passenger_name, '|', q.email, '|', q.phone, '|', q.sum_flights)
from
	(
	select a.passenger_id
		  ,a.passenger_name
		  ,cast(a.contact_data::json->'email' as text) as email
	  ,cast(a.contact_data::json->'phone' as text) as phone
	  ,sum(b.amount) as sum_flights
	from bookings.tickets a
		full outer join bookings.ticket_flights b
			on a.ticket_no = b.ticket_no
	group by a.passenger_id, a.passenger_name, a.contact_data
	having sum(b.amount) = (select min(f.summa)
							from
								(
								select sum(b.amount) as summa
								from bookings.tickets a
									full outer join bookings.ticket_flights b
										on a.ticket_no = b.ticket_no
								group by a.passenger_id
								) as f)
	order by a.passenger_id, a.passenger_name, email, phone
	) as q;

/*9.	Вывести контактную информацию по пассажиру(ам) (passenger_id, passenger_name, contact_data) и общее время в полётах, для пассажира, который провёл максимальное время в полётах*/

INSERT INTO results
select 9, concat(passenger_id, '|', passenger_name, '|', contact_data, '|', sum_duration)
from
	(select passenger_id, passenger_name, contact_data, sum(actual_duration) sum_duration,
	rank() over(order by sum(actual_duration) desc) rank_sum_duration
	from tickets t1
	join ticket_flights using(ticket_no)
	join flights_v using(flight_id)
	where actual_duration is not null
	group by ticket_no) t2
where rank_sum_duration = 1
order by passenger_id, passenger_name, contact_data;

/*10.	Вывести город(а) с количеством аэропортов больше одного*/

INSERT INTO results
select 10, city
from airports
group by city
having count(city) > 1
order by city;

/*11.	Вывести город(а), у которого самое меньшее количество городов прямого сообщения*/

INSERT INTO results
select 11, a.city
from bookings.flights f
	left join bookings.airports a
		on f.departure_airport = a.airport_code
group by a.city
having count(distinct f.arrival_airport) = (
										select min(a.count)
										from
											(
											select departure_airport
												  ,count(distinct arrival_airport) as count
											from bookings.flights
											group by departure_airport
											) as a
											)
order by city;

/*12.	Вывести пары городов, у которых нет прямых сообщений исключив реверсные дубликаты*/

INSERT INTO results
select 12, concat(f.airoport_dep, '|', f.airoport_arr)
from
	(
	select z.airoport_dep
		  ,z.airoport_arr
	from
		(
		select a.city as airoport_dep, b.city as airoport_arr
		from bookings.airports a
			cross join bookings.airports b

		except

		select distinct departure_city, arrival_city
		from bookings.flights_v
		) as z
	where z.airoport_dep <= z.airoport_arr

	union

	select z.airoport_arr
		  ,z.airoport_arr
	from
		(
		select a.city as airoport_dep, b.city as airoport_arr
		from bookings.airports a
			cross join bookings.airports b

		except

		select distinct departure_city, arrival_city
		from bookings.flights_v
		) as z
	where z.airoport_dep > z.airoport_arr
	) as f
where f.airoport_dep != f.airoport_arr
order by f.airoport_dep, f.airoport_arr;

/*13.	Вывести города, до которых нельзя добраться без пересадок из Москвы?*/

INSERT INTO results
select distinct 13, departure_city
from routes
where departure_city != 'Москва'
	and departure_city not in (
		select arrival_city from routes
		where departure_city = 'Москва');

/*14.	Вывести модель самолета, который выполнил больше всего рейсов*/

INSERT INTO results
select 14, a.model
from bookings.flights f
	left join bookings.aircrafts a
		on f.aircraft_code = a.aircraft_code
where f.status = 'Arrived'
	or f.status = 'Departed'
group by a.model
order by count(*) desc
limit 1;

/*15.	Вывести модель самолета, который перевез больше всего пассажиров*/

INSERT INTO results
select 15, a.model
from bookings.flights f
	left join bookings.aircrafts a
		on f.aircraft_code = a.aircraft_code
	right join bookings.ticket_flights tf
		on f.flight_id = tf.flight_id
	left join bookings.tickets t
		on t.ticket_no = tf.ticket_no
where f.status = 'Arrived'
	or f.status = 'Departed'
group by a.model
order by count(t.passenger_id) desc
limit 1;

/*16.	Вывести отклонение в минутах суммы запланированного времени перелета от фактического по всем перелётам*/

INSERT INTO results
select 16, cast(extract(epoch from sum((actual_arrival - actual_departure) - (scheduled_arrival - scheduled_departure)))/60 as int)
from bookings.flights
where actual_arrival is not null;

/*17.	Вывести города, в которые осуществлялся перелёт из Санкт-Петербурга 2017-08-11*/

INSERT INTO results
select distinct 17,
	arrival_city as response
from flights_v f
where departure_city = 'Санкт-Петербург'
and date_trunc('day',actual_departure_local) = '2017-08-11'
order by 1,2;
commit;

/*18.	Вывести перелёт(ы) с максимальной стоимостью всех билетов*/

INSERT INTO results
select 18, f.flight_id
from bookings.flights f
	inner join bookings.ticket_flights tf
		on f.flight_id = tf.flight_id
group by f.flight_id
having sum(tf.amount) =
					(
					select max(summa)
					from
						(
						select sum(tf.amount) as summa
						from bookings.flights f
							inner join bookings.ticket_flights tf
								on f.flight_id = tf.flight_id
						group by f.flight_id
						) as f
					);


/*19.	Выбрать дни в которых было осуществлено минимальное количество перелётов*/

INSERT INTO results
select 19, date_departure
from
	(select actual_departure::date date_departure, count(flight_id) count_flight,
	min(count(flight_id)) over() min_count_flight
	from flights f
	where actual_departure is not null
	group by actual_departure::date) t
where count_flight = min_count_flight
order by date_departure;


/*20.	Вывести среднее количество вылетов в день из Москвы за 09 месяц 2016 года*/

INSERT INTO results
SELECT 20, avg(fl_cnt) FROM
(
	SELECT to_char(coalesce(actual_departure_local , scheduled_departure_local), 'YYYY-MM-dd') as dt, count(flight_id) as fl_cnt FROM bookings.flights_v f
	where to_char(coalesce(actual_departure_local , scheduled_departure_local), 'YYYY-MM') = '2017-08'
	and departure_city = 'Москва'
	and status in ('Departed','Arrived')
	group by to_char(coalesce(actual_departure_local , scheduled_departure_local), 'YYYY-MM-dd')
) t1;

/*21.	Вывести топ 5 городов у которых среднее время перелета до пункта назначения больше 3 часов*/

INSERT INTO results
SELECT 21, t1.departure_city FROM
(select departure_city,
		   extract (epoch from avg(actual_duration))/60/60 as avg_dur,
		   count(flight_id) as cnt_flights
	from flights_v
	where status = 'Arrived'
	group by departure_city
	having extract (epoch from avg(actual_duration))/60/60 > 3
	order by 3 desc
	limit 5) t1;
