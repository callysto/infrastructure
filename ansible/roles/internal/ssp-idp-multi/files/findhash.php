#!/usr/bin/php
<?php

require_once('/var/simplesamlphp-1.15.4/www/_include.php');

function generateHash($userID) {
  $srcID = 'set17:saml20-idp-hostedset57:https://hub.callysto.ca/simplesaml/saml2/idp/metadata.php';
  $dstID = 'set16:saml20-sp-remoteset34:https://hub.callysto.ca/shibboleth';

  $secretSalt = \SimpleSAML\Utils\Config::getSecretSalt();
  $uidData = 'uidhashbase'.$secretSalt;
  $uidData .= strlen($srcID).':'.$srcID;
  $uidData .= strlen($dstID).':'.$dstID;
  $uidData .= strlen($userID).':'.$userID;
  $uidData .= $secretSalt;

  $uid = hash('sha1', $uidData);

  return $uid;
}

$email = $argv[1];

// First try with just the email address.
$hash = generateHash($email);
if (file_exists("/tank/home/$hash")) {
  echo "==> Home Directory detected:\n";
  echo "OAuth: $hash\n\n";
}

// Next try with all federation members.
// Repeat this block for each federation.

// Load the federation metadata here
require_once('/var/simplesamlphp-1.15.4/metadata/metarefresh-pikafederation/saml20-idp-remote.php');

foreach ($metadata as $key => $value) {
  $entityID = $value['entityid'];
  $userID = $email . '!' . $entityID;

  $hash = generateHash($userID);
  if (file_exists("/tank/home/$hash")) {
    $displayName = $value['UIInfo']['DisplayName']['en'];
    echo "==> Home Directory detected:\n";
    echo "$displayName ($entityID): $hash\n\n";
  }

}
