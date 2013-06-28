--[Create] At 2012-03-28 By chen.wu
--Input: @GateNo, @Date
--Output: Current Payment Cost Calculation Expression

if OBJECT_ID(N'Fn_PaymentCostCalcExp',N'FN') is not null
begin
	drop function Fn_PaymentCostCalcExp;
end
go

create function Fn_PaymentCostCalcExp
(
	@GateNo varchar(4),
	@Date datetime = null
)
returns nvarchar(max)
as
begin
	declare @RefMaxAmt bigint;  
	set @RefMaxAmt = 100000000000000;
	
	set @Date = isnull(@Date, getdate());
	
	declare @CostCalcExp nvarchar(max);
	
	declare @LatestRule table
	(
		GateNo char(4),
		CostRuleType varchar(20),
		ApplyDate datetime		
	);
	
	insert into @LatestRule
	(
		GateNo,
		CostRuleType,
		ApplyDate
	)
	select
		r1.GateNo,
		r1.CostRuleType,
		r1.ApplyDate		
	from
		Table_GateCostRule r1
	where
		r1.ApplyDate <= @Date
		and
		r1.GateNo = @GateNo
		and
		not exists(select
						1
					from
						Table_GateCostRule r2
					where
						r2.GateNo = @GateNo
						and
						r2.ApplyDate <= @Date
						and
						r2.ApplyDate > r1.ApplyDate)

	
	--1. Cost Rule By Trans	
	if exists (
		select
			1
		from
			@LatestRule
		where
			CostRuleType = 'ByTrans')
	begin
		--select * from Table_CostRuleByTrans
		set @CostCalcExp = stuff(
			(select
			'��' +
			case when 
				ByTrans.FeeType = 'Fixed'
				and
				ByTrans.RefMinAmt = 0
				and
				ByTrans.RefMaxAmt = @RefMaxAmt
			then 
				N'ÿ�ʳɱ�' + convert(varchar, convert(decimal(10, 3), ByTrans.FeeValue/100)) + N'Ԫ'
			when
				ByTrans.FeeType = 'Fixed'
				and
				(ByTrans.RefMinAmt <> 0
				 or
				 ByTrans.RefMaxAmt <> @RefMaxAmt) 
			then 
				N'ÿ�ʽ��׽����'+ convert(varchar,convert(decimal(20,2),ByTrans.RefMinAmt/100))  
				+ case when 
						   ByTrans.RefMaxAmt != @RefMaxAmt
					   then 
						   '-' + convert(varchar,convert(decimal(20,2),ByTrans.RefMaxAmt/100)) + N'Ԫʱ��'
					   else
						   N'����ʱ��'
				  end	
					 + N'ÿ�ʳɱ�' + convert(varchar, convert(decimal(10, 3), ByTrans.FeeValue/100)) + N'Ԫ'
			when 
				ByTrans.FeeType = 'Percent'
				and
				ByTrans.RefMinAmt = 0
				and
				ByTrans.RefMaxAmt = @RefMaxAmt 
			then
				N'������' + convert(varchar, convert(decimal(10, 3), ByTrans.FeeValue * 100)) + N'%��ȡ�ɱ�' 
			when
				ByTrans.FeeType = 'Percent'
				and
				(ByTrans.RefMinAmt <> 0
				 or
				 ByTrans.RefMaxAmt <> @RefMaxAmt) 
			then
				N'ÿ�ʽ��׽����'+ convert(varchar,convert(decimal(20,2),ByTrans.RefMinAmt/100))  
				+ case when 
					ByTrans.RefMaxAmt != @RefMaxAmt
				then 
					'-' + convert(varchar,convert(decimal(20,2),ByTrans.RefMaxAmt/100)) + N'Ԫʱ��'
				else
					N'����ʱ��'
				end	
				+ N'������' + convert(varchar, convert(decimal(10, 3), ByTrans.FeeValue * 100)) + N'%��ȡ�ɱ�'
			else
				N''
			end
		from
			@LatestRule LatestRule
			inner join
			Table_CostRuleByTrans ByTrans
			on
				LatestRule.GateNo = ByTrans.GateNo
				and
				LatestRule.ApplyDate = ByTrans.ApplyDate
		for xml path('')),
		1,
		1,
		'')
	end
	--2. Cost Rule By Year
	else if exists (
		select
			1
		from
			@LatestRule
		where
			CostRuleType = 'ByYear')
	begin
		--select distinct FeeType from Table_CostRuleByYear
		set @CostCalcExp = stuff(
			(select
			'��' +
			case when 
				ByYear.FeeType = 'Fixed'
				and
				ByYear.RefMinAmt = 0
				and
				ByYear.RefMaxAmt = @RefMaxAmt
			then
				case when ByYear.GateGroup <> 0 then N'������' else N'' end
				+ N'����ɱ�' + convert(varchar, convert(decimal(10, 3), ByYear.FeeValue/100)) + N'Ԫ'
			when
				ByYear.FeeType = 'Fixed'
				and
				(ByYear.RefMinAmt <> 0
				 or
				 ByYear.RefMaxAmt <> @RefMaxAmt) 
			then 
				N'�꽻�׽����'+ convert(varchar,convert(decimal(20,2),ByYear.RefMinAmt/100))  
				+ case when 
						   ByYear.RefMaxAmt != @RefMaxAmt
					   then 
						   '-' + convert(varchar,convert(decimal(20,2),ByYear.RefMaxAmt/100)) + N'Ԫʱ��'
					   else
						   N'����ʱ��'
				  end	
				  + case when ByYear.GateGroup <> 0 then N'������' else N'' end			  
				  + N'����ɱ�' + convert(varchar, convert(decimal(10, 3), ByYear.FeeValue/100)) + N'Ԫ'
			when 
				ByYear.FeeType = 'Split'
				and
				ByYear.RefMinAmt = 0
				and
				ByYear.RefMaxAmt = @RefMaxAmt 
			then
				N'������' + convert(varchar, convert(decimal(10, 3), ByYear.FeeValue * 100)) + N'%��Ϊ����ɱ�' 
			when
				ByYear.FeeType = 'Split'
				and
				(ByYear.RefMinAmt <> 0
				 or
				 ByYear.RefMaxAmt <> @RefMaxAmt) 
			then
				N'�꽻�׽����'+ convert(varchar,convert(decimal(20,2),ByYear.RefMinAmt/100))  
				+ case when 
					ByYear.RefMaxAmt != @RefMaxAmt
				then 
					'-' + convert(varchar,convert(decimal(20,2),ByYear.RefMaxAmt/100)) + N'Ԫʱ��'
				else
					N'����ʱ��'
				end	
				+ N'������' + convert(varchar, convert(decimal(10, 3), ByYear.FeeValue * 100)) + N'%��Ϊ����ɱ�'
			else
				N''
			end
		from
			@LatestRule LatestRule
			inner join
			Table_CostRuleByYear ByYear
			on
				LatestRule.GateNo = ByYear.GateNo
				and
				LatestRule.ApplyDate = ByYear.ApplyDate
		for xml path('')),
		1,
		1,
		'')	
	end
	--3 Cost Rule By Merchant
	else if exists(
		select
			1
		from
			@LatestRule
		where
			CostRuleType = 'ByMer')
	begin
		set @CostCalcExp = stuff(
			(select
			'��' +
			case when 
				ByMer.FeeType = 'Percent'
			then
				N'���������̻�' + rtrim(ByMer.MerchantNo) + N'�������׽���' + convert(varchar, convert(decimal(10, 3), ByMer.FeeValue * 100)) + N'%��ȡ�ɱ�' 
			when
				ByMer.FeeType = 'Fixed'
			then
				N'���������̻�' + rtrim(ByMer.MerchantNo) + N'��ÿ�ʳɱ�' + convert(varchar, convert(decimal(10, 3), ByMer.FeeValue/100)) + N'Ԫ'
			else
				N''
			end
		from
			@LatestRule LatestRule
			inner join
			Table_CostRuleByMer ByMer
			on
				LatestRule.GateNo = ByMer.GateNo
				and
				LatestRule.ApplyDate = ByMer.ApplyDate
		for xml path('')),
		1,
		1,
		'')
	end
	--4 Cost Rule By Upop
	else if exists(
		select
			1
		from
			@LatestRule
		where
			CostRuleType = 'ByUpop')
	begin
		--select * from Table_UpopCostRule
		set @CostCalcExp = stuff(
			(select
				'��' +
				case when
					ByUpop.CostRuleType = 'ByMer'
					and
					ByUpop.FeeType = 'Fixed'
				then 
					N'�̻���' + ByUpop.RuleObject + N' ÿ�ʳɱ�' + convert(varchar, convert(decimal(10, 3), ByUpop.FeeValue/100)) + N'Ԫ'
				when
					ByUpop.CostRuleType = 'ByMer'
					and
					ByUpop.FeeType = 'Percent'
				then 
					N'�̻���' + ByUpop.RuleObject + N' ������' + convert(varchar, convert(decimal(10, 3), ByUpop.FeeValue * 100)) + N'%��ȡ�ɱ�'
				when
					ByUpop.CostRuleType = 'ByMcc'
					and
					ByUpop.FeeType = 'Fixed'
				then
					N'MCC��' + ByUpop.RuleObject + N' ÿ�ʳɱ�' + convert(varchar, convert(decimal(10, 3), ByUpop.FeeValue/100)) + N'Ԫ'
				when
					ByUpop.CostRuleType = 'ByMcc'
					and
					ByUpop.FeeType = 'Percent'
				then 
					N'MCC��' + ByUpop.RuleObject + N' ������' + convert(varchar, convert(decimal(10, 3), ByUpop.FeeValue * 100)) + N'%��ȡ�ɱ�'
				when
					ByUpop.CostRuleType = 'ByCd'
				then
					N'�����ǣ�' + ByUpop.RuleObject + N' ������' + convert(varchar, convert(decimal(10, 3), ByUpop.FeeValue * 100)) + N'%��ȡ�ɱ�'
				else
					N''
				end
			from
				Table_UpopCostRule ByUpop
			where
				ByUpop.ApplyDate <= @Date
				and
				not exists(select
								1
							from
								Table_UpopCostRule ByUpop2
							where
								ByUpop2.ApplyDate <= @Date
								and
								ByUpop2.RuleObject = ByUpop.RuleObject
								and
								ByUpop2.ApplyDate > ByUpop.ApplyDate)
			for xml path('')),
			1,
			1,
			'')
	end		
	else
	begin
		set @CostCalcExp = N'';
	end

	return @CostCalcExp;
end


