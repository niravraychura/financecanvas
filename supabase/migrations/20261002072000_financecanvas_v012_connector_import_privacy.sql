-- Strengthen connector-import sensitive-data enforcement without blocking
-- ordinary private financial statement data.

create or replace function financecanvas_private.luhn_valid(p_value text)
returns boolean
language plpgsql
immutable
security invoker
set search_path = pg_catalog
as $$
declare
  v_digits text := regexp_replace(coalesce(p_value,''),'[^0-9]','','g');
  v_sum integer := 0;
  v_digit integer;
  v_double boolean := false;
  i integer;
begin
  if char_length(v_digits)<13 or char_length(v_digits)>19 then
    return false;
  end if;

  for i in reverse char_length(v_digits)..1 loop
    v_digit := substr(v_digits,i,1)::integer;
    if v_double then
      v_digit := v_digit*2;
      if v_digit>9 then v_digit:=v_digit-9; end if;
    end if;
    v_sum := v_sum+v_digit;
    v_double := not v_double;
  end loop;

  return (v_sum % 10)=0;
end;
$$;

revoke all on function financecanvas_private.luhn_valid(text)
from public, anon, authenticated;

create or replace function financecanvas_private.assert_import_payload_safe(p_payload jsonb)
returns void
language plpgsql
security invoker
set search_path = pg_catalog, public, financecanvas_private
as $$
declare
  v_original text := coalesce(p_payload::text,'');
  v_text text := lower(v_original);
  v_match text[];
begin
  if v_text ~ '"(cvv|cvc|pin|upi_pin|otp|password|passcode|private_key|seed|mnemonic|recovery_phrase|api_key|access_token|refresh_token)"\s*:'
     or v_text ~ '(cvv|cvc|otp|upi[ _-]?pin|atm[ _-]?pin|password|passcode|private[ _-]?key|seed[ _-]?phrase|recovery[ _-]?phrase|api[ _-]?key|access[ _-]?token|refresh[ _-]?token)\s*[:=]\s*[^,}" ]+'
  then
    raise exception 'CRITICAL_SECRET_DETECTED: connector import payload contains a prohibited authentication/payment secret';
  end if;

  if v_text ~ '"(aadhaar|aadhar|vid|pan|passport|tax_id|full_card_number|card_number|account_number)"\s*:'
     or v_text ~ '(account(?:[ _-]?number)?|a/c)\s*[:=]?\s*[0-9]{6,20}'
  then
    raise exception 'HIGH_RISK_IDENTIFIER_DETECTED: connector import payload contains a prohibited full identifier';
  end if;

  if upper(v_original) ~ '[A-Z]{5}[0-9]{4}[A-Z]'
  then
    raise exception 'HIGH_RISK_IDENTIFIER_DETECTED: connector import payload appears to contain a PAN';
  end if;

  for v_match in
    select regexp_matches(v_original,'(?:[0-9][ -]?){13,19}','g')
  loop
    if financecanvas_private.luhn_valid(v_match[1]) then
      raise exception 'FULL_CARD_NUMBER_DETECTED: store only a masked card identifier or final four digits';
    end if;
  end loop;
end;
$$;

revoke all on function financecanvas_private.assert_import_payload_safe(jsonb)
from public, anon, authenticated;
