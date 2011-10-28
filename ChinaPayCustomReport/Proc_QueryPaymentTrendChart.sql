if OBJECT_ID(N'Proc_QueryPaymentTrendChart', N'P') is not null
begin
	drop procedure Proc_QueryPaymentTrendChart;
end
go

create procedure Proc_QueryPaymentTrendChart
	@StartDate datetime = '2011-01-01',
	@EndDate datetime = '2011-09-30',
	@Unit nchar(4) = N'月'	
as
begin
--1. Check Input
IF (@StartDate IS NULL OR @EndDate IS NULL OR ISNULL(@Unit, N'') = N'') 
	BEGIN RAISERROR (N'Parameters cannot be empty.', 16, 1); 
END
IF (@StartDate > @EndDate) 
	BEGIN RAISERROR (N'StartDate cannot larger than EndDate.', 16, 1); 
END 

--2. Prepare Temp Data
--2.1 Create temp time period table
CREATE TABLE #TimePeriod
(
	PeriodStart datetime NOT NULL PRIMARY KEY, 
	PeriodEnd datetime NOT NULL
); 

--2.2 Fill #TimePeriod
DECLARE @PeriodStart datetime; 
DECLARE @PeriodEnd datetime;
SET @PeriodStart = @StartDate;
SET @PeriodEnd = 
	CASE @Unit 
	  WHEN N'周' THEN DATEADD(week, 1, @PeriodStart) 
      WHEN N'月' THEN DATEADD(month, 1, @PeriodStart) 
      WHEN N'季度' THEN DATEADD(QUARTER, 1, @PeriodStart) 
      WHEN N'半年' THEN DATEADD(QUARTER, 2, @PeriodStart) 
      WHEN N'年' THEN DATEADD(year, 1, @PeriodStart) 
      ELSE @PeriodStart 
    END; 
      
WHILE (@PeriodEnd < @EndDate) 
BEGIN	
	INSERT INTO #TimePeriod
	(
		PeriodStart, 
		PeriodEnd
	)
	VALUES 
	(
		@PeriodStart,
		@PeriodEnd
	);

	SET @PeriodStart = @PeriodEnd;
	SET @PeriodEnd = 
		CASE @Unit 
		  WHEN N'周' THEN DATEADD(week, 1, @PeriodStart) 
		  WHEN N'月' THEN DATEADD(month, 1, @PeriodStart) 
		  WHEN N'季度' THEN DATEADD(QUARTER, 1, @PeriodStart) 
		  WHEN N'半年' THEN DATEADD(QUARTER, 2, @PeriodStart) 
		  WHEN N'年' THEN DATEADD(year, 1, @PeriodStart) 
		  ELSE @PeriodStart 
		END;
END
          
INSERT INTO #TimePeriod
(
	PeriodStart, 
	PeriodEnd
)
VALUES 
(
	@PeriodStart, 
	dateadd(day, 1,@EndDate)
);

--3. Get Result
SELECT 
	TimePeriod.PeriodStart AS PeriodStart, 
	Convert(Decimal,SUM(FactDailyTrans.SucceedTransCount))/1000 AS SucceedCount, 
    Convert(Decimal,SUM(FactDailyTrans.SucceedTransAmount))/1000000 AS SucceedAmount
FROM 
	FactDailyTrans 
	INNER JOIN
    #TimePeriod TimePeriod 
    ON 
		FactDailyTrans.DailyTransDate >= TimePeriod.PeriodStart
		AND 
		FactDailyTrans.DailyTransDate < TimePeriod.PeriodEnd
GROUP BY 
	TimePeriod.PeriodStart
ORDER BY
	TimePeriod.PeriodStart; 

--4. Clear temp tables
DROP TABLE #TimePeriod;

End