# /packages/intranet-trans-invoices/www/new-3.tcl
#
# Copyright (C) 2003-2004 Project/Open
#
# All rights reserved. Please check
# http://www.project-open.com/license/ for details.


# ---------------------------------------------------------------
# 1. Page Contract
# ---------------------------------------------------------------

ad_page_contract { 
    Receives the list of tasks to invoice and creates an invoice form
    similar to /intranet-invoicing/www/new in order to create a new
    invoice.<br>
    @param include_task A list of im_trans_task IDs to include in the
           new invoice
    @param company_id All include_tasks need to be from the same
           company.
    @param invoice_currency: EUR or USD

    @author frank.bergmann@project-open.com
} {
    include_task:multiple
    company_id:integer
    invoice_currency
    target_cost_type_id:integer
    { return_url ""}
}

# ---------------------------------------------------------------
# Defaults & Security
# ---------------------------------------------------------------

set user_id [ad_maybe_redirect_for_registration]
set org_company_id $company_id

if {"" == $return_url} {set return_url [im_url_with_query] }
set todays_date [db_string get_today "select sysdate from dual"]
set page_focus "im_header_form.keywords"
set view_name "invoice_tasks"

set bgcolor(0) " class=roweven"
set bgcolor(1) " class=rowodd"
set required_field "<font color=red size=+1><B>*</B></font>"

set price_url_base "/intranet-trans-invoices/price-lists/new"

set number_format "99990.099"

if {![im_permission $user_id add_invoices]} {
    ad_return_complaint "[_ intranet-trans-invoices.lt_Insufficient_Privileg]" "
    <li>[_ intranet-trans-invoices.lt_You_dont_have_suffici]"    
}

# ---------------------------------------------------------------
# Gather invoice data
# ---------------------------------------------------------------

# Build the list of selected tasks ready for invoicing
set in_clause_list [list]
foreach selected_task $include_task {
    lappend in_clause_list $selected_task
}
set tasks_where_clause "task_id in ([join $in_clause_list ","])"

# We already know that all tasks are from the same company,
# and we asume that the company_id is set from new-2.tcl.

# Create the default values for a new invoice.
#
# Calculate the next invoice number by calculating the maximum of
# the "reasonably build numbers" currently available

set cost_type_id $target_cost_type_id
set type_name [db_string type_name "select im_category_from_id(:target_cost_type_id)"]

set button_text "[_ intranet-trans-invoices.Create_Invoice]"
set page_title "[_ intranet-trans-invoices.New_Invoice]"
set context_bar [im_context_bar [list /intranet/invoices/ "[_ intranet-trans-invoices.Finance]"] $page_title]
set invoice_id [im_new_object_id]
set invoice_nr [im_next_invoice_nr -invoice_type_id $target_cost_type_id]
set invoice_date $todays_date
set default_payment_days [ad_parameter -package_id [im_package_cost_id] "DefaultCompanyInvoicePaymentDays" "" 30] 
set due_date [db_string get_due_date "select to_date(to_char(sysdate,'YYYY-MM-DD'),'YYYY-MM-DD') + $default_payment_days from dual"]
set provider_id [im_company_internal]
set customer_id $company_id

set cost_status_id [im_cost_status_created]
set tax 0
set note ""
set default_vat 0
set default_payment_method_id ""
set default_invoice_template_id ""

# ---------------------------------------------------------------
# Gather company data from company_id
# ---------------------------------------------------------------

db_1row invoices_info_query ""


# Logic to determine the default contact for this invoice.
# This logic only makes sense if there is exactly one
# project to be invoiced.
set project_ids [db_list project_list "
	select distinct project_id
	from im_trans_tasks
	where $tasks_where_clause
"]

set company_contact_id $accounting_contact_id
if {1 == [llength $project_ids]} { 
    set project_id [lindex $project_ids 0]
    set company_contact_id [im_invoices_default_company_contact $customer_id $project_id]
}


db_1row accounting_contact_info "
    select
        im_name_from_user_id(:company_contact_id) as company_contact_name,
        im_email_from_user_id(:company_contact_id) as company_contact_email
    "


# ---------------------------------------------------------------
# Render the "Invoice Data" and "Receipient" blocks
# ---------------------------------------------------------------
set invoice_data_html "
        <tr><td align=middle class=rowtitle colspan=2>[_ intranet-trans-invoices.Invoice_Data]</td></tr>
        <tr>
          <td  class=rowodd>[_ intranet-trans-invoices.Invoice_nr]:</td>
          <td  class=rowodd> 
            <input type=text name=invoice_nr size=15 value='$invoice_nr'>
          </td>
        </tr>
        <tr> 
          <td  class=roweven>[_ intranet-trans-invoices.Invoice_date]:</td>
          <td  class=roweven> 
            <input type=text name=invoice_date size=15 value='$invoice_date'>
          </td>
        </tr>
        <tr> 
          <td class=rowodd>[_ intranet-trans-invoices.Type]</td>
          <td class=rowodd>[im_cost_type_select cost_type_id $cost_type_id [im_cost_type_company_doc]]</td>
        </tr>\n"

if {$cost_type_id == [im_cost_type_invoice]} {
    append invoice_data_html "
        <tr> 
          <td class=roweven>[_ intranet-trans-invoices.Payment_terms]</td>
          <td class=roweven> 
            <input type=text name=payment_days size=5 value='$default_payment_days'>
            days date of invoice</td>
        </tr>
        <tr> 
          <td class=rowodd>[_ intranet-trans-invoices.Payment_Method]</td>
          <td class=rowodd>[im_invoice_payment_method_select payment_method_id $default_payment_method_id]</td>
        </tr>\n"
}

append invoice_data_html "
        <tr> 
          <td class=roweven>[_ intranet-trans-invoices.Invoice_template]:</td>
          <td class=roweven>[im_cost_template_select template_id $default_invoice_template_id]</td>
        </tr>
"

set receipient_html "
        <tr><td align=center valign=top class=rowtitle colspan=2>[_ intranet-trans-invoices.Recipient]</td></tr>
        <tr> 
          <td  class=rowodd>[_ intranet-trans-invoices.Company_name]</td>
          <td  class=rowodd>
            <A href=/intranet/companies/view?company_id=$company_id>$company_name</A>
          </td>
        </tr>
        <tr> 
          <td  class=roweven>[_ intranet-trans-invoices.VAT]</td>
          <td  class=roweven>$vat_number</td>
        </tr>
        <tr> 
          <td  class=rowodd>[_ intranet-core.Contact]</td>
          <td  class=rowodd>
	    [im_company_contact_select company_contact_id $company_contact_id $company_id]
          </td>
        </tr>
        <tr> 
          <td  class=roweven>[_ intranet-trans-invoices.Adress]</td>
          <td  class=roweven>$address_line1 <br> $address_line2</td>
        </tr>
        <tr> 
          <td  class=rowodd>[_ intranet-trans-invoices.Zip]</td>
          <td  class=rowodd>$address_postal_code</td>
        </tr>
        <tr> 
          <td  class=roweven>[_ intranet-trans-invoices.Country]</td>
          <td  class=roweven>$country_name</td>

        </tr>
        <tr> 
          <td  class=rowodd>[_ intranet-trans-invoices.Phone]</td>
          <td  class=rowodd>$phone</td>
        </tr>
        <tr> 
          <td  class=roweven>[_ intranet-trans-invoices.Fax]</td>
          <td  class=roweven>$fax</td>
        </tr>
        <tr> 
          <td  class=rowodd>[_ intranet-trans-invoices.Email]</td>
          <td  class=rowodd>$company_contact_email</td>
        </tr>
"

# ---------------------------------------------------------------
# 6. Select and render invoicable items 
# ---------------------------------------------------------------

set sql "
select 
	t.task_id,
	t.task_units,
	t.task_name,
	t.billable_units,
	t.task_uom_id,
	t.task_type_id,
	t.project_id,
	im_category_from_id(t.task_uom_id) as uom_name,
	im_category_from_id(t.task_type_id) as type_name,
	im_category_from_id(t.task_status_id) as task_status,
	im_category_from_id(t.target_language_id) as target_language,
	p.project_name,
	p.project_path,
	p.project_path as project_short_name
from 
	im_trans_tasks t,
	im_projects p
where 
	$tasks_where_clause
	and t.project_id = p.project_id
order by
	project_id, task_id
"

set task_table "
<tr> 
  <td class=rowtitle>[_ intranet-trans-invoices.Task_Name]</td>
  <td class=rowtitle>[_ intranet-trans-invoices.Units]</td>
  <td class=rowtitle>[_ intranet-trans-invoices.Billable_Units]</td>
  <td class=rowtitle>[_ intranet-trans-invoices.Target]</td>
  <td class=rowtitle>[_ intranet-trans-invoices.UoM] [im_gif help "Unit of Measure"]</td>
  <td class=rowtitle>[_ intranet-trans-invoices.Type]</td>
  <td class=rowtitle>[_ intranet-trans-invoices.Status]</td>
</tr>
"

ns_log Notice "before rendering the task list $invoice_id"

set task_table_rows ""
set ctr 0
set colspan 7
set old_project_id 0
db_foreach select_tasks $sql {

    # insert intermediate headers for every project
    if {$old_project_id != $project_id} {
	append task_table_rows "
		<tr><td colspan=$colspan>&nbsp;</td></tr>
		<tr>
		  <td class=rowtitle colspan=$colspan>
	            <A href=/intranet/projects/view?project_id=$project_id>
		      $project_short_name
		    </A>: $project_name
	          </td>
		  <input type=hidden name=select_project value=$project_id>
		</tr>\n"
	set old_project_id $project_id
    }

    append task_table_rows "
        <input type=hidden name=im_trans_task value=$task_id>
	<tr $bgcolor([expr $ctr % 2])> 
	  <td align=left>$task_name</td>
	  <td align=right>$task_units</td>
	  <td align=right>$billable_units</td>
	  <td align=right>$target_language</td>
	  <td align=right>$uom_name</td>
	  <td>$type_name</td>
	  <td>$task_status</td>
	</tr>"
    incr ctr
}

if {![string equal "" $task_table_rows]} {
    append task_table $task_table_rows
} else {
    append task_table "<tr><td colspan=$colspan align=center>[_ intranet-trans-invoices.No_tasks_found]</td></tr>"
}

# ---------------------------------------------------------------
# 7. Select and format the sum of the invoicable items
# for a new invoice
# ---------------------------------------------------------------

    # start formatting the list of sums with the header...
    set task_sum_html "
        <tr align=center> 
          <td class=rowtitle>[_ intranet-trans-invoices.Order]</td>
          <td class=rowtitle>[_ intranet-trans-invoices.Description]</td>
          <td class=rowtitle>[_ intranet-trans-invoices.Units]</td>
          <td class=rowtitle>[_ intranet-trans-invoices.UOM]</td>
          <td class=rowtitle>[_ intranet-trans-invoices.Rate]</td>
        </tr>
    "

    # Start formatting the "reference price list" as well, even though it's going
    # to be shown at the very bottom of the page.
    #
    set price_colspan 11
    set reference_price_html "
        <tr><td align=middle class=rowtitle colspan=$price_colspan>[_ intranet-trans-invoices.Reference_Prices]</td></tr>
        <tr>
          <td class=rowtitle>[_ intranet-trans-invoices.Company]</td>
          <td class=rowtitle>[_ intranet-trans-invoices.UoM]</td>
          <td class=rowtitle>[_ intranet-trans-invoices.Task_Type]</td>
          <td class=rowtitle>[_ intranet-trans-invoices.Target]</td>
          <td class=rowtitle>[_ intranet-trans-invoices.Source]</td>
          <td class=rowtitle>[_ intranet-trans-invoices.Subject_Area]</td>
<!--          <td class=rowtitle>[_ intranet-trans-invoices.Valid_From]</td>	-->
<!--          <td class=rowtitle>[_ intranet-trans-invoices.Valid_Through]</td>	-->
          <td class=rowtitle>[_ intranet-core.Note]</td>
          <td class=rowtitle>[_ intranet-trans-invoices.Price]</td>
        </tr>\n"


    # Calculate the sum of tasks (distinct by TaskType and UnitOfMeasure)
    # and determine the price of each line using a custom definable
    # function.
    set task_sum_inner_sql "
select
	sum(t.billable_units) as task_sum,
	t.task_type_id,
	t.task_uom_id,
	t.source_language_id,
	t.target_language_id,
	p.company_id,
	p.project_id,
	p.subject_area_id
from 
	im_trans_tasks t,
	im_projects p
where 
	$tasks_where_clause
	and t.project_id=p.project_id
group by
	t.task_type_id,
	t.task_uom_id,
	p.company_id,
	p.project_id,
	t.source_language_id,
	t.target_language_id,
	p.subject_area_id
"

    # Take the "Inner Query" with the data (above) and add some "long names" 
    # (categories, client names, ...) for pretty output
    set task_sum_sql "
select
	s.task_sum,
	s.task_type_id,
	s.subject_area_id,
	s.source_language_id,
	s.target_language_id,
	s.task_uom_id,
	c_type.category as task_type,
	c_uom.category as task_uom,
	c_target.category as target_language,
	s.company_id,
	s.project_id,
	p.project_name,
	p.project_path,
	p.project_path as project_short_name,
	p.company_project_nr
from
	im_categories c_uom,
	im_categories c_type,
	im_categories c_target,
	im_projects p,
	($task_sum_inner_sql) s
where
	s.task_type_id=c_type.category_id(+)
	and s.task_uom_id=c_uom.category_id(+)
	and s.target_language_id=c_target.category_id(+)
	and s.project_id=p.project_id(+)
order by
	p.project_id
    "


    # Calculate the price for the specific service.
    # Complicated undertaking, because the price depends on a number of variables,
    # depending on client etc. As a solution, we act like a search engine, return 
    # all prices and rank them according to relevancy. We take only the first 
    # (=highest rank) line for the actual price proposal.
    #
    set reference_price_sql "
select 
	p.price_id,
	p.relevancy as price_relevancy,
	trim(' ' from to_char(p.price,:number_format)) as price,
	p.company_id as price_company_id,
	p.uom_id as uom_id,
	p.task_type_id as task_type_id,
	p.target_language_id as target_language_id,
	p.source_language_id as source_language_id,
	p.subject_area_id as subject_area_id,
	p.valid_from,
	p.valid_through,
	p.price_note,
	c.company_path as price_company_name,
        im_category_from_id(p.uom_id) as price_uom,
        im_category_from_id(p.task_type_id) as price_task_type,
        im_category_from_id(p.target_language_id) as price_target_language,
        im_category_from_id(p.source_language_id) as price_source_language,
        im_category_from_id(p.subject_area_id) as price_subject_area
from
	(
		(select 
			im_trans_prices_calc_relevancy (
				p.company_id,:company_id,
				p.task_type_id, :task_type_id,
				p.subject_area_id, :subject_area_id,
				p.target_language_id, :target_language_id,
				p.source_language_id, :source_language_id
			) as relevancy,
			p.price_id,
			p.price,
			p.company_id,
			p.uom_id,
			p.task_type_id,
			p.target_language_id,
			p.source_language_id,
			p.subject_area_id,
			p.valid_from,
			p.valid_through,
			p.note as price_note
		from im_trans_prices p
		where
			uom_id=:task_uom_id
			and currency=:invoice_currency
		)
	) p,
	im_companies c
where
	p.company_id=c.company_id
	and relevancy >= 0
order by
	p.relevancy desc,
	p.company_id,
	p.uom_id
    "


    set ctr 1
    set old_project_id 0
    set colspan 6
    set target_language_id ""
    db_foreach task_sum $task_sum_sql {

	# insert intermediate headers for every project
	if {$old_project_id != $project_id} {
	    append task_sum_html "
		<tr><td class=rowtitle colspan=$price_colspan>
	          <A href=/intranet/projects/view?project_id=$project_id>$project_short_name</A>:
	          $company_project_nr
	        </td></tr>\n"

	    # Also add an intermediate header to the price list
	    append reference_price_html "
		<tr><td class=rowtitle colspan=$price_colspan>
	          <A href=/intranet/projects/view?project_id=$project_id>$project_short_name</A>:
	          $company_project_nr
	        </td></tr>\n"
	
	    set old_project_id $project_id
	}

	# Determine the price from a ranked list of "price list hits"
	# and render the "reference price list"
	set price_list_ctr 1
	set best_match_price 0
	db_foreach references_prices $reference_price_sql {

	    ns_log Notice "new-3: company_id=$company_id, uom_id=$uom_id => price=$price, relevancy=$price_relevancy"
	    # Take the first line of the result list (=best score) as a price proposal:
	    if {$price_list_ctr == 1} {set best_match_price $price}

	    set price_url [export_vars -base $price_url_base { company_id price_id return_url }]

	    append reference_price_html "
        <tr>
          <td class=$bgcolor([expr $price_list_ctr % 2])>
		<a href=\"[export_vars -base "/intranet/companies/view" { {company_id $price_company_id} return_url }]\">$price_company_name</a>
	  </td>
          <td class=$bgcolor([expr $price_list_ctr % 2])>$price_uom</td>
          <td class=$bgcolor([expr $price_list_ctr % 2])>$price_task_type</td>
          <td class=$bgcolor([expr $price_list_ctr % 2])>$price_target_language</td>
          <td class=$bgcolor([expr $price_list_ctr % 2])>$price_source_language</td>
          <td class=$bgcolor([expr $price_list_ctr % 2])>$price_subject_area</td>
<!--          <td class=$bgcolor([expr $price_list_ctr % 2])>$valid_from</td>		-->
<!--          <td class=$bgcolor([expr $price_list_ctr % 2])>$valid_through</td> 	-->
          <td class=$bgcolor([expr $price_list_ctr % 2])>[string_truncate -len 30 $price_note]</td>
          <td class=$bgcolor([expr $price_list_ctr % 2])>
		<a href=\"$price_url\">$price $invoice_currency</a>
	  </td>
        </tr>\n"
	
	    incr price_list_ctr
	}

	# Add an empty line to the price list to separate prices form item to item
	append reference_price_html "<tr><td colspan=$price_colspan>&nbsp;</td></tr>\n"

	append task_sum_html "
	<tr $bgcolor([expr $ctr % 2])> 
          <td>
	    <input type=text name=item_sort_order.$ctr size=2 value='$ctr'>
	  </td>
          <td>
	    <input type=text name=item_name.$ctr size=40 value='$task_type ($target_language)'>
	  </td>
          <td align=right>
	    <input type=text name=item_units.$ctr size=4 value='$task_sum'>
	  </td>
          <td align=right>
	    <input type=hidden name=item_uom_id.$ctr value='$task_uom_id'>
	    $task_uom
	  </td>
          <td align=right>
	    <input type=text name=item_rate.$ctr size=3 value='$best_match_price'>
	    <input type=hidden name=item_currency.$ctr value='$invoice_currency'>
	    $invoice_currency
	  </td>
        </tr>
	<input type=hidden name=item_project_id.$ctr value='$project_id'>
	<input type=hidden name=item_type_id.$ctr value='$task_type_id'>\n"

	incr ctr
    }

# ---------------------------------------------------------------
# 9. Render VAT and TAX
# ---------------------------------------------------------------

set grand_total_html "
        <tr>
          <td> 
          </td>
          <td colspan=4 align=right> 
            <table border=0 cellspacing=1 cellpadding=0>
              <tr> 
                <td>[_ intranet-trans-invoices.VAT]</td>
                <td><input type=text name=vat value='$default_vat' size=4> % &nbsp;</td>
              </tr>
            </table>
          </td>
        </tr>
        <tr> 
          <td> 
          </td>
          <td colspan=4 align=right> 
            <table border=0 cellspacing=1 cellpadding=0>
              <tr> 
                <td>[_ intranet-trans-invoices.TAX]</td>
                <td><input type=text name=tax value='$tax' size=4> % &nbsp;</td>
              </tr>
            </table>
          </td>
        </tr>
        <tr> 
          <td>&nbsp; </td>
          <td colspan=6 align=right> 
              <input type=submit name=submit value='$button_text'>
          </td>
        </tr>
"

# ---------------------------------------------------------------
# 10. Join all parts together
# ---------------------------------------------------------------

ns_log Notice "new-3: before joining the parts together"

set page_body "
[im_costs_navbar "none" "/intranet/invoicing/index" "" "" [list]]

<form action=new-4 method=POST>
[export_form_vars customer_id provider_id invoice_id cost_status_id return_url]

"

foreach task_id $in_clause_list {
    append page_body "<input type=hidden name=include_task value=$task_id>\n"
}

append page_body "
  <!-- Invoice Data and Receipient Tables -->
  <table cellpadding=0 cellspacing=0 bordercolor=#6699CC border=0 width=100%>
    <tr valign=top> 
      <td>

        <table border=0 cellPadding=0 cellspacing=2>
	  $invoice_data_html
<!--	  <tr><td colspan=2 align=right><input type=submit value='Update'></td></tr> -->
        </table>

      </td>
      <td></td>
      <td align=right>
        <table border=0 cellspacing=2 cellpadding=0 >
          $receipient_html</td>
        </table>
    </tr>
  </table>

  <!-- the list of tasks (invoicable items) -->
  <table cellpadding=2 cellspacing=2 border=0 width='100%'>
    $task_table
  </table>

  <!-- the list of task sums, distinguised by type and UOM -->
  <table width=100%>
    <tr>
      <td align=right><table border=0 cellspacing=2 cellpadding=1>
        $task_sum_html
        $grand_total_html
      </td>
    </tr>
  </table>

</form>

<!-- the list of reference prices -->
<table>
  $reference_price_html
</table>
"

db_release_unused_handles

ad_return_template