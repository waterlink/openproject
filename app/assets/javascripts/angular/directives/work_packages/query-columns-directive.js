angular.module('openproject.workPackages.directives')

.directive('queryColumns', ['WorkPackagesTableHelper', function(WorkPackagesTableHelper) {

  return {
    restrict: 'E',
    replace: true,
    templateUrl: '/templates/work_packages/query_columns.html',
    compile: function(tElement) {
      return {
        pre: function(scope) {
          scope.moveColumns = function (columnNames, fromColumns, toColumns) {
            angular.forEach(getColumnIndexes(columnNames, fromColumns), function(index) {
              toColumns.push(fromColumns.splice(index, 1).first());
            });
          };

          scope.moveSelectedColumnBy = function(by) {
            var nameOfColumnToBeMoved = scope.markedSelectedColumns.first();
            WorkPackagesTableHelper.moveColumnBy(scope.columns, nameOfColumnToBeMoved, by);
          };

          function getColumnIndexes(columnNames, columns) {
            return columnNames
              .map(function(name) {
                return WorkPackagesTableHelper.getColumnIndexByName(columns, name);
              })
              .filter(function(columnIndex){
                return columnIndex !== -1;
              });
          }

        }
      };
    }
  };
}]);