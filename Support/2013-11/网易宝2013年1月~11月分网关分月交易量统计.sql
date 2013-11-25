select
	f.GateNo,
	(select GateDesc from Table_GateRoute where GateNo = f.GateNo) as GateName,
	CONVERT(nchar(4),YEAR(f.DailyTransDate))+N'年'+CONVERT(nvarchar(2),MONTH(f.DailyTransDate))+N'月' as YearMonth,
	SUM(f.SucceedTransCount) as SucceedCnt,
	SUM(f.SucceedTransAmount)/100.0 as SucceedAmt
from
	FactDailyTrans f
where
	f.MerchantNo = '808080052202103'
	and
	f.DailyTransDate >= '2013-01-01'
group by
	f.GateNo,
	CONVERT(nchar(4),YEAR(f.DailyTransDate))+N'年'+CONVERT(nvarchar(2),MONTH(f.DailyTransDate))+N'月'
