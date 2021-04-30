-- issue/honor no locks and be the deadlock victim if needed
set transaction isolation level read uncommitted;
set deadlock_priority -10
set nocount on

-- tax state
declare @sa as varchar(2) = 'XX'

-- tax period - year/month
declare	@pd AS DATETIME = dateadd(month,-1,getdate())
declare @py as int = year(@pd)
declare @pm as int = month(@pd)

;with o as (
select
	o.ord_hdrnumber
from
	orderheader o
where
	o.ord_status = 'CMP' --completed orders
	-- orders started in this period
	and ( year(o.ord_startdate) = @py and month(o.ord_startdate) = @pm )
    and ord_revtype2 != 'PMP' --skip pumpouts
	--note that some freightitems will get filtered out below
	-- due to commodity class restrictions
	-- and some others at the bottom due to not having a stop in this state
)
--freight in scope - LULs
, lul as (
select
	  o.ord_hdrnumber
	, f.fgt_number
	, f.fgt_shipper
	, f.fgt_supplier
	, f.fgt_accountof
	, f.cmd_code
	, f.fgt_quantity
	, f.fgt_weight
	, s.stp_arrivaldate
	, s.cmp_id
from
	o
	join stops s on s.ord_hdrnumber = o.ord_hdrnumber
		and s.stp_event = 'lul'
	join freightdetail f on f.stp_number = s.stp_number
	join commodity c on c.cmd_code = f.cmd_code
		--note this filters out orders that are not in
		-- the commodity classes we report taxes for
		and c.cmd_class in ('500', '600', '700')
)
, fmt as (
select
	  [ord_hdrnumber]         = lul.ord_hdrnumber
	, [fgt_number]            = lul.fgt_number
	, [bol]                   = bol.ref_number
	, [shipped]               = format(coalesce(parentLLD.stp_departuredate,firstLLD.stp_departuredate),'yyyy-MM-ddTHH:mm:sszzz')
	, [delivered]             = format(lul.stp_arrivaldate,'yyyy-MM-ddTHH:mm:sszzz')
	, [gross]                 = cast(lul.fgt_quantity as int)
	, [net]                   = cast(lul.fgt_weight as int)
	, [shipper.cmp_id]        = lul.fgt_shipper
	, [shipper.name]          = shipper.name
	, [shipper.state]         = shipper.state
	, [shipper.tcn]           = replace(shipper_tcn.not_text,'-','')
	, [supplier.cmp_id]       = lul.fgt_supplier
	, [supplier.name]         = supplier.name
	, [supplier.tax_id]       = replace(supplier.tax_id,'-','')
	, [consignor.cmp_id]      = lul.fgt_accountof
	, [consignor.name]        = consignor.name
	, [consignor.tax_id]      = replace(consignor.tax_id,'-','')
	, [consignee.cmp_id]      = lul.cmp_id
	, [consignee.name]        = consignee.name
	, [consignee.address]     = consignee.address
	, [consignee.city]        = consignee.city
	, [consignee.state]       = consignee.state
	, [consignee.zip]         = consignee.zip
	, [consignee.tax_id]      = replace(consignee.tax_id,'-','')
	, [consignee.dep]         = consignee_dep.not_text
	, [schedule]              = case
		when shipper.state =  @sa and consignee.state != @sa then '14A'
        when shipper.state != @sa and consignee.state =  @sa then '14B'
        when shipper.state =  @sa and consignee.state =  @sa then '14C'
		end
	, [cmd_code]              = case
		when cmd_code = 'yourcode1' then 'theircode1'
		when cmd_code = 'yourcode2' then 'theircode2'
		when cmd_code in ('yourcode3','yourcode4','yourcode5') then 'theircode3'
        else 'nocode-' + lul.cmd_code end
from
	lul
	outer apply (
		select top 1
			  [name] = cmp_name
			, [state] = cmp_state
		from
			company
		where
			cmp_id = lul.fgt_shipper
	) shipper
	outer apply (
		select top 1
			n.not_text
		from
			notes n
		where
			n.nre_tablekey = lul.fgt_shipper
			and n.not_type = 'tin'
	) shipper_tcn
	outer apply (
		select top 1
			  [name] = cmp_name
			, [tax_id] = cmp_taxid
		from
			company
		where
			cmp_id = lul.fgt_supplier
	) supplier
	outer apply (
		select top 1
			  [name] = cmp_name
			, [tax_id] = cmp_taxid
		from
			company
		where
			cmp_id = lul.fgt_accountof
	) consignor
	--note DEP is only needed for FL
	outer apply (
		select top 1
			  [name] = cmp_name
			, [address] = cmp_address1
			, [city] = (
				select top 1 cty.cty_name
				from city cty
				where cty.cty_code = cmp_city
			)
			, [state] = cmp_state
			, [zip] = cmp_zip
			, [tax_id] = cmp_taxid
		from
			company
		where
			cmp_id = lul.cmp_id
	) consignee
	outer apply (
		select top 1
			n.not_text
		from
			notes n
		where
			n.nre_tablekey = lul.cmp_id
			and n.not_type = 'dep'
	) consignee_dep
	outer apply (
		select top 1
			rn.ref_number
		from
			referencenumber rn
		where
			rn.ord_hdrnumber = lul.ord_hdrnumber
			and rn.ref_tablekey = lul.fgt_number
			and rn.ref_table = 'freightdetail'
			and rn.ref_type = 'shiptk'
		order by
			rn.last_updateby desc
	) bol
	outer apply (
		-- look for a parent loaded freight record that matches the dropped freight and get it's departure datetime
		select top 1
			s.stp_departuredate
		from
			freightdetail lf
			join stops s on s.stp_number = lf.stp_number
				and s.stp_event = 'lld'
		where
			lf.fgt_parentcmd_fgt_number = lul.fgt_number
	) parentLLD
	outer apply (
		-- if there is no parent loaded freight record,
		--   get the last load time for this shipper on this order
		--   where the departure takes place before the unload arrivaldate
		--   and the departuredate is not empty, by default this should be in asc
		--   order so we'll get the first stop for that shipper
		select top 1
			--get the last departer datetime
			stp_departuredate
		from
			--where we stopped
			stops
		where
			-- for this order
			ord_hdrnumber = lul.ord_hdrnumber
			-- for this load
			and stp_event = 'lld'
			-- for the shipper listed for this freight ite
			and cmp_id = lul.fgt_shipper
			-- where the departure date was not blank/null
			and coalesce(stp_departuredate,'') != ''
			-- and it was prior to when we arrived to drop off this freight
			and stp_departuredate < lul.stp_arrivaldate
	) firstLLD
where
	@sa in (shipper.state,consignee.state)
)
select * from fmt
order by ord_hdrnumber, fgt_number