eclipse-package-index
=====================

Collect and index metadata from a broad range of eclipse repositories.

The included 'bookmarks.xml' file was created from the current set of repositories
I am using in Eclipse, selected them all with ctrl-a, and then clicking 'export'
to generate the bookmarks file directly from Eclipse. It is included for demonstration
purposes.

The 'bookmarks_to_cache.pl' script will read the bookmarks.xml file and create a
cache folder containing various cached files downloaded directly from all of the
active repositories in 'bookmarks.xml'.

The 'cache_to_index.pl' script will output a large XML index. Currently it should be
run in the following fashion 'perl cache_to_index.pl > full.xml'.

The 'find_from_index.pl' script will currently search through full.xml for the name
of a package in dot notation. It will then return the name of the package ( that
you could search for in Eclipse itself ) and the repository that package can be
found in. More extension searching will be added later.

Note that Eclipse repositories bounce around to each other. The 'cache' folder
created will end up containing quite a few more respositories than you may expect.
As a result, you will also get back multiple results when using 'find' for the same
package. This is normal and to be expected at this point.

Example usage and results of 'find':
```
$ perl find.pl ^org.eclipse.birt$
Unit name: Business Intelligence and Reporting Tools
  Repo name: BIRT Update Site
  Site url: http://download.eclipse.org/birt/update-site/4.3

Unit name: Business Intelligence and Reporting Tools
  Repo name: BIRT Update Site
  Site url: http://download.eclipse.org/birt/update-site/4.3

Unit name: Business Intelligence and Reporting Tools
  Repo name: BIRT Update Site
  Site url: http://download.eclipse.org/birt/update-site/4.3

Unit name: Business Intelligence and Reporting Tools
  Repo name: Kepler
  Site url: http://download.eclipse.org/releases/kepler/201306260900

Unit name: Business Intelligence and Reporting Tools
  Repo name: Kepler
  Site url: http://download.eclipse.org/releases/kepler/201309270900

Unit name: Business Intelligence and Reporting Tools
  Repo name: Kepler
  Site url: http://download.eclipse.org/releases/kepler/201402280900
```
