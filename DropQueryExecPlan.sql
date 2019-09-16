select plan_handle, creation_time, last_execution_time, execution_count, qt.text
from sys.dm_exec_query_stats as qs
cross apply sys.dm_exec_sql_text (qs.[sql_handle]) AS qt
where qt.text like '%SpGetTransactionsInBasketLock%'


DBCC FREEPROCCACHE(0x05003000A9062B22A01B4F11E100000001000000000000000000000000000000000000000000000000000000)