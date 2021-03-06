@runtime
@runtime_extended3
@rhel-only
@jboss
Feature: SwitchYard Application Sub-Cartridge
  Scenario: Create Delete one EAP application with embedded SwitchYard
    Given a new jbosseap-6 type application
    
    When I embed a switchyard-0 cartridge into the application
    Then the eap module configuration file will exist
    
    When I remove the switchyard-0 cartridge from the application
    Then the eap module configuration file will not exist
    
    When I destroy the application
    
  Scenario: Create Delete one AS application with embedded SwitchYard
    Given a new jbossas-7 type application
    
    When I embed a switchyard-0 cartridge into the application
    Then the as module configuration file will exist
    
    When I remove the switchyard-0 cartridge from the application
    Then the eap module configuration file will not exist
    
    When I destroy the application
    
  Scenario: Create Delete one Non-JBoss application with embedded SwitchYard
    Given a new php-5.3 type application
    
    When I fail to embed a switchyard-0 cartridge into the application
    
    When I destroy the application
