#import "NSComparisonPredicate+MGLAdditions.h"

#import "NSPredicate+MGLAdditions.h"
#import "NSExpression+MGLAdditions.h"

@implementation NSComparisonPredicate (MGLAdditions)

- (mbgl::style::Filter)mgl_filter
{
    NSExpression *leftExpression = self.leftExpression;
    NSExpression *rightExpression = self.rightExpression;
    NSExpressionType leftType = leftExpression.expressionType;
    NSExpressionType rightType = rightExpression.expressionType;
    BOOL isReversed = ((leftType == NSConstantValueExpressionType || leftType == NSAggregateExpressionType)
                       && rightType == NSKeyPathExpressionType);
    switch (self.predicateOperatorType) {
        case NSEqualToPredicateOperatorType: {
            mbgl::style::EqualsFilter eqFilter;
            eqFilter.key = self.mgl_keyPath.UTF8String;
            eqFilter.value = self.mgl_constantValue;

            // Convert == nil to NotHasFilter.
            if (eqFilter.value.is<mbgl::NullValue>()) {
                mbgl::style::NotHasFilter notHasFilter;
                notHasFilter.key = eqFilter.key;
                return notHasFilter;
            }

            return eqFilter;
        }
        case NSNotEqualToPredicateOperatorType: {
            mbgl::style::NotEqualsFilter neFilter;
            neFilter.key = self.mgl_keyPath.UTF8String;
            neFilter.value = self.mgl_constantValue;

            // Convert != nil to HasFilter.
            if (neFilter.value.is<mbgl::NullValue>()) {
                mbgl::style::HasFilter hasFilter;
                hasFilter.key = neFilter.key;
                return hasFilter;
            }

            return neFilter;
        }
        case NSGreaterThanPredicateOperatorType: {
            if (isReversed) {
                mbgl::style::LessThanFilter ltFilter;
                ltFilter.key = self.mgl_keyPath.UTF8String;
                ltFilter.value = self.mgl_constantValue;
                return ltFilter;
            } else {
                mbgl::style::GreaterThanFilter gtFilter;
                gtFilter.key = self.mgl_keyPath.UTF8String;
                gtFilter.value = self.mgl_constantValue;
                return gtFilter;
            }
        }
        case NSGreaterThanOrEqualToPredicateOperatorType: {
            if (isReversed) {
                mbgl::style::LessThanEqualsFilter lteFilter;
                lteFilter.key = self.mgl_keyPath.UTF8String;
                lteFilter.value = self.mgl_constantValue;
                return lteFilter;
            } else {
                mbgl::style::GreaterThanEqualsFilter gteFilter;
                gteFilter.key = self.mgl_keyPath.UTF8String;
                gteFilter.value = self.mgl_constantValue;
                return gteFilter;
            }
        }
        case NSLessThanPredicateOperatorType: {
            if (isReversed) {
                mbgl::style::GreaterThanFilter gtFilter;
                gtFilter.key = self.mgl_keyPath.UTF8String;
                gtFilter.value = self.mgl_constantValue;
                return gtFilter;
            } else {
                mbgl::style::LessThanFilter ltFilter;
                ltFilter.key = self.mgl_keyPath.UTF8String;
                ltFilter.value = self.mgl_constantValue;
                return ltFilter;
            }
        }
        case NSLessThanOrEqualToPredicateOperatorType: {
            if (isReversed) {
                mbgl::style::GreaterThanEqualsFilter gteFilter;
                gteFilter.key = self.mgl_keyPath.UTF8String;
                gteFilter.value = self.mgl_constantValue;
                return gteFilter;
            } else {
                mbgl::style::LessThanEqualsFilter lteFilter;
                lteFilter.key = self.mgl_keyPath.UTF8String;
                lteFilter.value = self.mgl_constantValue;
                return lteFilter;
            }
        }
        case NSInPredicateOperatorType: {
            if (isReversed) {
                if (leftType == NSConstantValueExpressionType && [leftExpression.constantValue isKindOfClass:[NSString class]]) {
                    [NSException raise:NSInvalidArgumentException
                                format:@"CONTAINS not supported for string comparison."];
                }
                [NSException raise:NSInvalidArgumentException
                            format:@"Predicate cannot compare values IN attribute."];
            }
            mbgl::style::InFilter inFilter;
            inFilter.key = leftExpression.keyPath.UTF8String;
            inFilter.values = rightExpression.mgl_aggregateMBGLValue;
            return inFilter;
        }
        case NSContainsPredicateOperatorType: {
            if (!isReversed) {
                if (rightType == NSConstantValueExpressionType && [rightExpression.constantValue isKindOfClass:[NSString class]]) {
                    [NSException raise:NSInvalidArgumentException
                                format:@"IN not supported for string comparison."];
                }
                [NSException raise:NSInvalidArgumentException
                            format:@"Predicate cannot compare attribute CONTAINS values."];
            }
            mbgl::style::InFilter inFilter;
            inFilter.key = rightExpression.keyPath.UTF8String;
            inFilter.values = leftExpression.mgl_aggregateMBGLValue;
            return inFilter;
        }
        case NSBetweenPredicateOperatorType: {
            if (isReversed) {
                [NSException raise:NSInvalidArgumentException
                            format:@"Predicate cannot compare bounds BETWEEN attribute."];
            }
            if (![rightExpression.constantValue isKindOfClass:[NSArray class]]) {
                [NSException raise:NSInvalidArgumentException
                            format:@"Right side of BETWEEN predicate must be an array."]; // not NSSet
            }
            auto values = rightExpression.mgl_aggregateMBGLValue;
            if (values.size() != 2) {
                [NSException raise:NSInvalidArgumentException
                            format:@"Right side of BETWEEN predicate must have two items."];
            }
            mbgl::style::AllFilter allFilter;
            mbgl::style::GreaterThanEqualsFilter gteFilter;
            gteFilter.key = leftExpression.keyPath.UTF8String;
            gteFilter.value = values[0];
            allFilter.filters.push_back(gteFilter);
            mbgl::style::LessThanEqualsFilter lteFilter;
            lteFilter.key = leftExpression.keyPath.UTF8String;
            lteFilter.value = values[1];
            allFilter.filters.push_back(lteFilter);
            return allFilter;
        }
        case NSMatchesPredicateOperatorType:
        case NSLikePredicateOperatorType:
        case NSBeginsWithPredicateOperatorType:
        case NSEndsWithPredicateOperatorType:
        case NSCustomSelectorPredicateOperatorType:
            [NSException raise:NSInvalidArgumentException
                        format:@"NSPredicateOperatorType:%lu is not supported.", (unsigned long)self.predicateOperatorType];
    }

    return {};
}

- (NSString *)mgl_keyPath {
    NSExpression *leftExpression = self.leftExpression;
    NSExpression *rightExpression = self.rightExpression;
    NSExpressionType leftType = leftExpression.expressionType;
    NSExpressionType rightType = rightExpression.expressionType;
    if (leftType == NSKeyPathExpressionType && rightType == NSConstantValueExpressionType) {
        return leftExpression.keyPath;
    } else if (leftType == NSConstantValueExpressionType && rightType == NSKeyPathExpressionType) {
        return rightExpression.keyPath;
    }

    [NSException raise:NSInvalidArgumentException
                format:@"Comparison predicate must compare an attribute (as a key path) to a constant or vice versa."];
    return nil;
}

- (mbgl::Value)mgl_constantValue {
    NSExpression *leftExpression = self.leftExpression;
    NSExpression *rightExpression = self.rightExpression;
    NSExpressionType leftType = leftExpression.expressionType;
    NSExpressionType rightType = rightExpression.expressionType;
    mbgl::Value value;
    if (leftType == NSKeyPathExpressionType && rightType == NSConstantValueExpressionType) {
        value = rightExpression.mgl_constantMBGLValue;
    } else if (leftType == NSConstantValueExpressionType && rightType == NSKeyPathExpressionType) {
        value = leftExpression.mgl_constantMBGLValue;
    } else {
        [NSException raise:NSInvalidArgumentException
                    format:@"Comparison predicate must compare an attribute (as a key path) to a constant or vice versa."];
    }
    return value;
}

@end
