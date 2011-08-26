#!/usr/bin/perl -w
use strict;
################################################################################
# 
# dsh - distributed shell
#
# Authors : Jason Rappleye
#           Center for Computational Research at the University at Buffalo
#           rappleye@ccr.buffalo.edu
#
#           Matthew T. Piotrowski
#           Center for Computational Research at the University at Buffalo
#           mtp22@users.sourceforge.net
# 
# Last Modified: 07/17/2001
#
# Copyright (c) 2000-2001 State University of New York at Buffalo
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#
# Modification history:
#
# 03/17/2000 jcr : initial release
#
# 07/17/2001 mtp : added parallel execution of the command, added
#    verification of the status of the nodes before execution of the command,
#    based the removal of duplicate nodes on IP addresses instead of hostnames,
#    added standard error to the node output, fixed the quoting of shell
#    metacharacters, fixed the formatting of the output when the names of nodes
#    are different lengths, added the -e switch, implemented fanout, added the
#    -t switch, added the -f switch, fixed -h switch, reorganized the code, 
#    and renamed some variables; also incorporated Dale's changes
#    
################################################################################

# developer's note: if anything from here to the line of all #'s is edited,
# this change should also be reflected in the configuration script

use IO::Handle;
use Socket;
# if Term-ReadLine-Gnu is not installed, this call will not generate
# an error because the standard Perl distribution includes a Term-ReadLine
# module, which is what this call refers to.  This module, Term-ReadLine, is 
# mostly an interface to C readline libraries for other Perl modules (for 
# example, Term-ReadLine-Gnu); it doesn't implement many of the ReadLine 
# functions itself, but it does implement enough of these functions that 
# calling Term::ReadLine->new doesn't fail if Term-ReadLine-Gnu is not installed
use Term::ReadLine;

# User Configuration ###########################################################
# the command that is used to execute your command (the one you specify 
# to dsh) on the nodes you specify to dsh (note: if you change this command,
# for example, to ssh, you need to change the following variable also;
# in this example, you would change it to getservbyname("ssh", "tcp")
my $RSH_CMD = "/usr/bin/rsh";
# the port used to contact the nodes you specify to dsh
# (note: getservbyname looks in the file /etc/services to determine
# the port number, so make sure there is a line in this file which has
# the service you specify) (also note: if you change this value to a
# non-standard port, for example, 91 for ssh, you need to edit the RSH_CMD
# variable so that it contacts the remote service on this port, for example,
# my $RSH_CMD = "/usr/bin/ssh -p 91")
my $RSH_CMD_PORT = getservbyname("shell", "tcp") || "514";
# directory where the "node_groups" folder is located
my $BEOWULF_ROOT = $ENV{BEOWULF_ROOT} || "/usr/local/dsh";
# name of file containing all nodes; located in $BEOWULF_ROOT/node_groups/
my $ALL_NODES = "ALL";
# number of nodes to process in parallel (this is approximately 1/3 of the 
# number of processes that will be running at one time); the default is 
# the total number of nodes
my $fanout = $ENV{FANOUT};
# the default time to wait for a node to respond when checking to see if 
# we can rsh to the node (note: this can also be set at the command line
# with the -t switch)
my $DEFAULT_TIMEOUT = 5;
################################################################################

my ($cmd, $cmdStart, $group, $i, $justList, $longest_hostname_length, $node,
    $timeout, $force,
    @cmd, @node_groups, @nodes,
    %hostname_length, %ip_addresses, %NODE_OUTPUT, %pid);

&process_command_line_switches;
&process_remaining_args;
&check_that_there_are_node_groups_or_nodes_to_work_with;
&expand_node_groups_to_nodes;
&remove_duplicate_nodes;
&check_that_we_can_rsh_to_nodes;
&find_length_of_longest_node_name;
&process_command;
exit;

sub process_command_line_switches {
    if ($#ARGV == -1 && ! defined $ENV{"WCOLL"}) {
	print STDERR "$0: no nodes specified, check the dsh man " .
	             "page for the 4 ways to specify nodes\n";
	&usage;
	exit(1);
    }
    ARG: for ($i = 0; $i <= $#ARGV; $i++) {
      SWITCH: {
	# need to break when $ARGV[$i] doesn't start with a '-'
	if ($ARGV[$i] !~ /^\-/) {
	  last ARG;
	}
	if ($ARGV[$i] eq "-N") {
	  do {
	      # check to see if nodegroup passed to the -N switch begins with
	      # a minus sign (-); if so, it is possible that this is
	      # an actual filename, but more likely it is an error
	      if ($ARGV[++$i] =~ /^\-/) {
		  print STDERR "$0: invalid nodegroup \"$ARGV[$i]\" specified ";
		  print STDERR "with -N switch\n";
		  &usage;
		  exit(1);
	      }
	      foreach (split(",", $ARGV[$i])) {
		  push @node_groups, "$BEOWULF_ROOT/node_groups/$_";
	      }
	  # allow for spaces in node group list 
          # (e.g. dsh -N nodegroup1, nodegroup2)
	  } while ($ARGV[$i] =~ /,$/);
      
	  last SWITCH;
	}
	if ($ARGV[$i] eq "-a") { 
	  push @node_groups, "$BEOWULF_ROOT/node_groups/$ALL_NODES"; 
	  last SWITCH; 
	}
	if ($ARGV[$i] eq "-w") {
	  do {
	      # check to see if the first node name passed to the -w switch
	      # begins with a minus sign (-); if so, it is possible that this is
	      # an actual hostname, but more likely it is an error
	      if ($ARGV[++$i] =~ /^\-/) {
		  print STDERR "$0: invalid node \"$ARGV[$i]\" specified ";
		  print STDERR "with -w switch\n";
		  &usage;
		  exit(1);
	      }
	      push @nodes, split(",", $ARGV[$i]);
	      # allow for spaces in node list 
	      # (e.g. dsh -w node1, node2)
	  } while ($ARGV[$i] =~ /,$/);

	  last SWITCH; 
	}
	if ($ARGV[$i] eq "-q") {
	  $justList = 1;
	  last SWITCH;
	}
	if ($ARGV[$i] eq "-e") {
	  # check to see if the command passed to the -e switch begins
	  # with a minus sign (-); if so, it is possible that this is
	  # an actual command, but more likely it is an error
	  if ($ARGV[++$i] =~ /^\-/) {
	      print STDERR "$0: invalid command \"$ARGV[$i]\" specified ";
	      print STDERR "with -e switch\n";
	      &usage;
	      exit(1);
	  }
	  $cmd = $ARGV[$i];
	  last SWITCH;
	}
	if ($ARGV[$i] eq "-t") {
	  if ($ARGV[++$i] !~ /^-?\d+$/) {
	      print STDERR "$0: invalid timeout \"$ARGV[$i]\" specified with " .
		           "-t switch\n";
	      &usage;
	      exit(1);
	  }
	  $timeout = $ARGV[$i];
	  last SWITCH;
	}
	if ($ARGV[$i] eq "-f") {
	  $force = 1;
	  last SWITCH;
	}
	if ($ARGV[$i] eq "-h") {
	  &usage;
	  exit;
	}
	print STDERR "$0: invalid switch \"$ARGV[$i]\":\n";
	&usage;
	exit(1);
      }
    }
}

sub process_remaining_args {
    # the remaining arguments are parts of the command to send to the nodes
    $cmdStart = $i;
    push @cmd, @ARGV[$cmdStart..$#ARGV];
    $cmd ||= join(" ", @cmd);  # command could already be defined by -e switch

    # quote the remaining arguments so that they are not interpretted again
    # by the local shell
    # (note:  this will also quote the command specified by the -e switch,
    #         if that switch was used)
    $cmd = "\'" . $cmd . "\'";
}

sub check_that_there_are_node_groups_or_nodes_to_work_with {
    # if there are no node_groups or nodes specified, check to see if a file was
    # specified in the environment variable "WCOLL"
    if ((! @node_groups && ! @nodes)) {
	if (defined($ENV{WCOLL})) {
	    push @node_groups, $ENV{"WCOLL"};
	}
	else {
	    print STDERR "$0: no nodes specified, check the dsh man " .
			 "page for the 4 ways to specify nodes\n";
	    exit(1);
	}
    }
}

sub expand_node_groups_to_nodes {
    # place the nodes in each file into the @nodes array 
    foreach $group (@node_groups) {
      open (FILE_IN, "< $group") or
	print STDERR "$0: couldn't open file \"$group\" : $!\n"
	    and exit(1);
      while (<FILE_IN>) {
	chomp;
	push @nodes, $_ unless (/^\#/ || /^\s*$/);
      }
      close FILE_IN;
    }
}

sub remove_duplicate_nodes {
    # remove duplicate nodes based on IP address
    my %ip_addresses_seen;
    @nodes = grep { my @name_lookup = gethostbyname($_)
			or print STDERR "$0: could not lookup " . 
			                "hostname \"$_\":  $!\n"
			     and exit(1);
		    # gethostbyname returns a couple different pieces of
		    # information; we are interested in the IP addresses
		    @name_lookup = @name_lookup[4 .. $#name_lookup];
		    my @resolved_ips = map {inet_ntoa($_)} @name_lookup;
		    # store one of the IP addresses so that $RSH_CMD
		    # doesn't have to translate it again later
		    $ip_addresses{$_} = $resolved_ips[0];
		    # check each resolved IP address to see if we have
		    # seen this node before; if we have seen any of
		    # the node's IP addresses before (either directly or
		    # by resolving an alias), we consider the node a duplicate
		    # and remove it from the list of nodes
		    my $have_seen_this_node = 0;
		    foreach my $ip (@resolved_ips) {
		       $have_seen_this_node = $ip_addresses_seen{$ip}++ ||
			                      $have_seen_this_node;
		    }
		    $have_seen_this_node == 0; } @nodes;
}

sub check_that_we_can_rsh_to_nodes {
    my $current_node_index = 0;
    while ($current_node_index < @nodes) {
	unless (we_can_rsh_to($nodes[$current_node_index])) {
	    unless ($force) {
		# couldn't rsh to node; ask user if we should continue
		# the program
		my $answer = "";
		until ($answer =~ /^y$/i || $answer =~ /^n$/i) {
		    print "The command hasn't been run on any nodes yet, " .
			  "would you like to continue?\n" .
			  "[y or n] ";
		    $answer = <STDIN>;
		    chomp($answer);
		}
		exit(1) unless ($answer =~ /^y$/i);
	    }
	    # remove node from node array
	    splice(@nodes, $current_node_index, 1);
	    # don't increment the current node index: the next node is actually
	    # at the current index because we removed an element from the array
	    # (note: this is the reason for using a while loop instead of a
	    #        foreach)
	    next;
	}
	$current_node_index++;
    }
    # exit if there are no nodes to work with
    if (@nodes == 0) {
	print STDERR "$0: Can't reach any of the specified nodes. Exiting...\n";
	exit(1);
    }
}

sub we_can_rsh_to {

    my $node = shift;

    my $node_ip_address = $ip_addresses{$node};
    my $port = $RSH_CMD_PORT;  # standard rsh port
    my $socket_structure = sockaddr_in($port, inet_aton($node_ip_address));

    # make the socket
    my $proto = getprotobyname('tcp');
    socket(SOCKET_HANDLE, PF_INET, SOCK_STREAM, $proto);

    # install timeout alarm
    local $SIG{ALRM} = sub {
	                     print STDERR "$0: couldn't connect to $node: \n" .
				          "$0: It appears the node is down " . 
					  "or unreachable.\n";
                             die "connection timed out\n";
               	       };
    # set the default timeout if timeout is not already defined
    $timeout = $DEFAULT_TIMEOUT unless defined($timeout);
    if ($timeout < 0) {
	print STDERR "$0: $timeout is not a valid timeout value.\n";
	print STDERR "$0: using default timeout value ($DEFAULT_TIMEOUT)\n";
	$timeout = $DEFAULT_TIMEOUT;
    }
    alarm($timeout);
    eval {
	unless (defined (connect(SOCKET_HANDLE, $socket_structure))) {
	  print STDERR "$0: couldn't connect to $node: \n" .
                       "$0: It appears the node is up but isn't " .
                       "allowing incoming rsh connections.\n";
	  die "connection refused\n";
	}
    };
    close(SOCKET_HANDLE);
    alarm(0);
    if ($@) {
	# couldn't connect to node
	return undef;
    }
    else {
	# connected to node successfully
	return 1;
    }
}

# find the length of the longest node name to properly format the node output
sub find_length_of_longest_node_name {
    $longest_hostname_length = 0;
    foreach $node(@nodes) {
	my $current_hostname_length = length $node;
	if ($current_hostname_length > $longest_hostname_length) {
	    $longest_hostname_length = $current_hostname_length;
	}
	$hostname_length{$node} = $current_hostname_length;
    }
}

sub process_command {
    if ($justList) {
      print join("\n", @nodes), "\n";
      exit(0);
    }

    if ($cmd && ($cmd ne '\'\'')) {
	&run_cmd_in_parallel();
    }
    else {
	print << 'INTERACTIVE_DSH';
--------------------------------interactive dsh---------------------------------
- This prompt features command history (using the up and down arrows), command
  completion (relative to the local computer), and command editing (for example,
  the home and end keys).
- Commands preceded by an exclamation point (!) will be run on the local
  computer. Note that these local commands will have "2>&1" appended to 
  merge standard error and standard output
--------------------------------------------------------------------------------
INTERACTIVE_DSH
      my $term = Term::ReadLine->new("DSH");
      while ($cmd = $term->readline("dsh> ")) {
	# check to see if the command is a local command
	if ($cmd =~ s/^!//) {
	  print "executing $cmd\n";
          my $LOCAL_OUTPUT = new IO::Handle;
          if (my $pid = open($LOCAL_OUTPUT, "-|")) {}
	  elsif (defined $pid) {
	      exec "$cmd 2>&1"
		  or print "couldn't run command '$cmd': $!\n"
		      and exit;
	  }
	  else {
	      print STDERR "$0: can't fork additional process to " .
		           "run command '$cmd'\n";
	  }
          while (<$LOCAL_OUTPUT>) {
	      print "local computer: \t", $_;
	  }
	  close($LOCAL_OUTPUT);
	  # flush STDOUT
	  $| = 1;
	  $| = 0;
	}
	# check to see if the user entered exit
	elsif ($cmd =~ m/^\s*exit\s*$/) {
	    exit;
	}
	else {
	  $cmd = "\'" . $cmd . "\'";
	  &run_cmd_in_parallel();
	}
      }
    }
}

sub run_cmd_in_parallel {
  my $total_number_of_nodes = @nodes;
  # number of nodes to rsh to in parallel
  if (defined($fanout)) {
      # check the fanout value specified by the user
      if ($fanout < 1) {
	 print STDERR "$0: $fanout is not a valid fanout value:\n";
	 print STDERR "$0: using closest valid fanout value (1)\n";
	 $fanout = 1;
      }
      if ($fanout > $total_number_of_nodes) {
	 print STDERR "$0: the fanout value specified ($fanout) is larger " .
		      "than the number of nodes:\n";
	 print STDERR "$0: using closest valid fanout value " .
		      "($total_number_of_nodes)\n";
	 $fanout = $total_number_of_nodes;
      }
  }
  else {
      # default is the total number of nodes
      $fanout = $total_number_of_nodes;
  }
  print "executing $cmd\n";
  # flush STDOUT before forking to avoid duplicate output when STDOUT is
  # in block-buffered mode (for example, when the standard output of dsh is
  # redirected to a file)
  select STDOUT;
  $| = 1;
  $| = 0;
  # I haven't witnessed the same problem with STDERR as I have with STDOUT, but
  # to be safe, I am also flushing STDERR 
  select STDERR;
  $| = 1;
  $| = 0;
  for (my $starting_node = 0; 
       $starting_node < $total_number_of_nodes; 
       $starting_node += $fanout) {
    my $ending_node = $starting_node + $fanout - 1;
    if ($ending_node >= $total_number_of_nodes) {
	$ending_node = $#nodes;
    }
    foreach my $node (@nodes[$starting_node..$ending_node]) {
      FORK: {
	  $NODE_OUTPUT{$node} = new IO::Handle;
	  if ($pid{$node} = open($NODE_OUTPUT{$node}, "-|")) {}
	  elsif (defined $pid{$node}) {
	      exec "$RSH_CMD $ip_addresses{$node} $cmd 2>&1" 
		  # note: 2>&1 merges standard error with standard output
		  or print "couldn't $RSH_CMD to this node: $!\n"
		      and exit;
	  }
	  else {
	      print STDERR "$0: can't fork additional process to " .
		           "$RSH_CMD to $node.\n";
	      print STDERR "$0: command not run on $node: $!\n";
	  }
      }
    }
    # print node output to the screen in the same order as the @nodes array 
    foreach $node (@nodes[$starting_node..$ending_node]) {
	my $print_padding = 
	    " " x ($longest_hostname_length - $hostname_length{$node});
	# dereference hash before reading from file handle
	my $NODE_OUTPUT = $NODE_OUTPUT{$node};
	while (<$NODE_OUTPUT>) {
	    print "$node:$print_padding \t", $_;
	}
	close($NODE_OUTPUT);
    }
  }
}

sub usage {
    print << "USAGE";
usage: $0
    -a adds all nodes in the file \$BEOWULF_ROOT/node_groups/ALL
    -e 'command'
       executes the command on all the nodes
    -f if this flag is specified, dsh won't prompt the user whether or not to
       continue if a node is unreachable or refusing a remote connection
    -h display this information
    -N group1, group2, ... 
       adds the nodes in the files \$BEOWULF_ROOT/node_groups/group1,
       \$BEOWULF_ROOT/node_groups/group2, etc.
    -q lists the nodes where dsh would execute the command without actually
       executing the command
    -t time_in_seconds 
       specifies the time to wait for a node to respond before labelling it 
       "unreachable"
    -w node1, node2, ... 
       adds the nodes node1, node2, etc.
USAGE
}
