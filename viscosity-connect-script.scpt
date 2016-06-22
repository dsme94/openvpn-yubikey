-- Find the name of the VPN connection we're connecting to or disconnecting from.
tell application "Viscosity"
  set conn_state to ""
  set conn_name to ""

  set num_conns to count of connection
  repeat with conn_index from 1 to num_conns
    set conn_state to state of connection conn_index
    if conn_state is "Connecting" then
      set conn_name to name of connection conn_index
      exit repeat
    else if conn_state is "Connected" then
      set conn_name to name of connection conn_index
      exit repeat
    else if conn_state is "Disconnecting" then
      set conn_name to name of connection conn_index
      exit repeat
    end if
  end repeat
end tell

if conn_name is "" then
  -- Nothing is being connected or disconnected.
  display notification "No VPN connection is in connecting/disconnecting state"
  return
end if

-- Get the username.
set info to system info
set username to short user name of info

if conn_state is "Connecting" then
  -- Get the YubiKey token and pass along to the python script to insert into keychain.
  display dialog "Tap your YubiKey to generate an OTP" default answer ""
  set yubi_token to text returned of result
  do shell script "python /Users/" & username & "/Library/Application\\ Support/Viscosity/viscosity-connect-script.py '" & conn_state & "' '" & conn_name & "' '" & yubi_token & "'"
  display notification "Updated keychain password for " & username & "@" & conn_name
else
  -- Pass info to the python script to reset the password in the keychain.
  do shell script "/Users/" & username & "/Library/Application\\ Support/Viscosity/viscosity-connect-script.py '" & conn_state & "' '" & conn_name & "'"
  display notification "Reset keychain password for " & username & "@" & conn_name
end if

